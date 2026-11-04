using System.Net.Http;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json.Nodes;
using System.Windows.Media.Imaging;
using System.Windows.Media;
namespace SwarmStudio;

public sealed class SwarmClient : IDisposable {
    readonly HttpClient http=new(){Timeout=TimeSpan.FromMinutes(90)};
    readonly Uri root;
    public string? Session {get;private set;}
    public string Version {get;private set;}="";
    public SwarmClient(string address) {
        if(!Uri.TryCreate(address.Trim().TrimEnd('/')+"/",UriKind.Absolute,out var uri)||!new[]{"https","http"}.Contains(uri.Scheme)||!string.IsNullOrEmpty(uri.UserInfo)||uri.AbsolutePath!="/"||!string.IsNullOrEmpty(uri.Query))throw new ArgumentException("Bitte eine gültige Serveradresse ohne Unterpfad eingeben.");
        if(uri.Scheme=="http"&&!uri.IsLoopback)throw new ArgumentException("Für entfernte Geräte bitte die private HTTPS-Adresse von Tailscale verwenden.");root=uri;
    }
    public async Task<JsonObject> Call(string route,JsonObject data,CancellationToken ct=default) {
        using var content=new StringContent(data.ToJsonString(),Encoding.UTF8,"application/json");
        using var response=await http.PostAsync(new Uri(root,"API/"+route),content,ct);response.EnsureSuccessStatusCode();
        var obj=JsonNode.Parse(await response.Content.ReadAsStringAsync(ct))?.AsObject()??throw new IOException("Ungültige Serverantwort.");
        if(obj["error"]!=null)throw new IOException(obj["error"]!.ToString());return obj;
    }
    public async Task Connect(CancellationToken ct=default) {var r=await Call("GetNewSession",new(),ct);Session=r["session_id"]?.ToString()??throw new IOException("Keine Serversitzung verfügbar.");Version=r["version"]?.ToString()??"";}
    public async Task<List<ModelChoice>> Models(CancellationToken ct=default) {
        if(Session==null)await Connect(ct);
        var r=await Call("ListModels",new(){["session_id"]=Session,["path"]="",["depth"]=10,["subtype"]="Stable-Diffusion"},ct);
        var models=new List<ModelChoice>();var all=r["files"]?.AsArray()??[];
        foreach(var m in all) {
            string name=m?["name"]?.ToString()??"",arch=m?["architecture"]?.ToString()??"";if(name.Length==0)continue;
            if(arch.Contains("stable-diffusion-xl")||name.Contains("sd_xl_base",StringComparison.OrdinalIgnoreCase))models.Add(new(name,"SDXL · "+Path.GetFileNameWithoutExtension(name),arch));
            if(name.Contains("HighNoise",StringComparison.OrdinalIgnoreCase)&&name.Contains("Wan2.2-I2V",StringComparison.OrdinalIgnoreCase)) {
                string low=name.Replace("HighNoise","LowNoise",StringComparison.OrdinalIgnoreCase);
                if(all.Any(x=>x?["name"]?.ToString()==low))models.Add(new(name,"Wan 2.2 · Bildanimation Q4",arch,low));
            }
        }return models;
    }
    public async Task Interrupt(CancellationToken ct=default){if(Session!=null)await Call("InterruptAll",new(){["session_id"]=Session,["other_sessions"]=false},ct);}
    public static string ImageData(string file) {
        if(new FileInfo(file).Length>30*1024*1024)throw new IOException("Startbilder dürfen höchstens 30 MB groß sein.");
        using var stream=File.OpenRead(file);var decoder=BitmapDecoder.Create(stream,BitmapCreateOptions.PreservePixelFormat,BitmapCacheOption.OnLoad);BitmapSource img=decoder.Frames[0];
        double scale=Math.Min(1,2048d/Math.Max(img.PixelWidth,img.PixelHeight));if(scale<1)img=new TransformedBitmap(img,new ScaleTransform(scale,scale));
        var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(img));using var output=new MemoryStream();encoder.Save(output);return "data:image/png;base64,"+Convert.ToBase64String(output.ToArray());
    }
    static double? Number(JsonNode? n)=>double.TryParse(n?.ToString(),System.Globalization.NumberStyles.Float,System.Globalization.CultureInfo.InvariantCulture,out var d)?d:null;
    public async Task<List<string>> Generate(JsonObject body,IProgress<RenderProgress> progress,CancellationToken ct) {
        body["session_id"]=Session;
        var wsUri=new UriBuilder(new Uri(root,"API/GenerateText2ImageWS")){Scheme=root.Scheme=="https"?"wss":"ws"}.Uri;
        using var socket=new ClientWebSocket();socket.Options.KeepAliveInterval=TimeSpan.FromSeconds(25);await socket.ConnectAsync(wsUri,ct);
        await socket.SendAsync(Encoding.UTF8.GetBytes(body.ToJsonString()),WebSocketMessageType.Text,true,ct);
        var outputs=new SortedDictionary<int,string>();var buffer=new byte[65536];
        while(socket.State==WebSocketState.Open) {
            using var msg=new MemoryStream();WebSocketReceiveResult result;
            do {result=await socket.ReceiveAsync(new ArraySegment<byte>(buffer),ct);if(result.MessageType==WebSocketMessageType.Close)break;msg.Write(buffer,0,result.Count);if(msg.Length>32*1024*1024)throw new IOException("Servernachricht zu groß.");}while(!result.EndOfMessage);
            if(result.MessageType==WebSocketMessageType.Close)break;if(result.MessageType!=WebSocketMessageType.Text)continue;
            var data=JsonNode.Parse(msg.ToArray())?.AsObject();if(data==null)continue;if(data["error"]!=null)throw new IOException(data["error"]!.ToString());
            if(data["gen_progress"] is JsonObject gp) {double? pct=Number(gp["overall_percent"]);progress.Report(new(pct is null?null:Math.Clamp(pct.Value*100,0,99),"KI berechnet dein Ergebnis …",gp["preview"]?.ToString()));}
            if(data["status"] is JsonObject st&&Number(st["loading_models"])>0)progress.Report(new(null,"Modell wird vorbereitet …"));
            if(data["image"] is JsonValue image){int index=int.TryParse(data["batch_index"]?.ToString(),out var batch)?batch:outputs.Count;outputs[index]=image.ToString();}
            if(data["discard_indices"] is JsonArray discard)foreach(int index in discard.Select(x=>int.TryParse(x?.ToString(),out int i)?i:-1))outputs.Remove(index);
            if(data["socket_intention"]?.ToString()=="close")break;
        }
        if(outputs.Count==0)throw new IOException("Der Server hat kein fertiges Ergebnis geliefert. Bitte den Auftrag prüfen, bevor du ihn erneut sendest.");return outputs.Values.ToList();
    }
    public static JsonObject ImageBody(RenderRequest r,string? model=null,int? steps=null)=>new(){["images"]=r.Count,["model"]=model??r.Model,["prompt"]=r.StyledPrompt,["negativeprompt"]=r.Negative,["width"]=r.Width,["height"]=r.Height,["steps"]=steps??r.Steps,["cfgscale"]=r.Cfg,["seed"]=r.Seed,["sampler"]="euler",["scheduler"]="normal"};
    public static JsonObject VideoBody(RenderRequest r,string image)=>new(){["images"]=1,["model"]=r.ImageModel,["prompt"]=r.StyledPrompt,["negativeprompt"]=r.Negative,["initimage"]=image,["initimagecreativity"]=0,["videomodel"]=r.Model,["videoswapmodel"]=r.SwapModel,["videoswappercent"]=0.5,["videoframes"]=r.Frames,["videosteps"]=r.Steps,["videocfg"]=r.Cfg,["videofps"]=16,["videoformat"]="h264-mp4",["videoresolution"]="Image",["width"]=r.Width,["height"]=r.Height,["sigmashift"]=5,["vaetilesize"]=256,["vaetemporaltilesize"]=16,["vaetemporaltileoverlap"]=4,["seed"]=r.Seed};
    public async Task<byte[]> Download(string relative,CancellationToken ct=default) {
        if(relative.StartsWith("data:image/",StringComparison.Ordinal))return Convert.FromBase64String(relative[(relative.IndexOf(',')+1)..]);
        if(Uri.TryCreate(relative,UriKind.Absolute,out _)||!relative.TrimStart('/').StartsWith("View/",StringComparison.Ordinal)||relative.Contains(".."))throw new IOException("Unsicherer Medienpfad vom Server abgelehnt.");
        using var response=await http.GetAsync(new Uri(root,relative.TrimStart('/')),HttpCompletionOption.ResponseHeadersRead,ct);response.EnsureSuccessStatusCode();if(response.Content.Headers.ContentLength>512L*1024*1024)throw new IOException("Datei zu groß.");
        await using var input=await response.Content.ReadAsStreamAsync(ct);using var output=new MemoryStream();var b=new byte[65536];int n;
        while((n=await input.ReadAsync(b,ct))>0){if(output.Length+n>512L*1024*1024)throw new IOException("Downloadlimit überschritten.");await output.WriteAsync(b.AsMemory(0,n),ct);}return output.ToArray();
    }
    public async Task<List<GalleryItem>> Render(RenderRequest r,IProgress<RenderProgress> progress,CancellationToken ct) {
        if(Session==null)await Connect(ct);List<string> paths;
        if(r.Mode=="video") {
            string input;
            if(!string.IsNullOrWhiteSpace(r.InputPath))input=ImageData(r.InputPath);
            else {progress.Report(new(null,"1 / 2 · Startbild entsteht …"));var imageReq=ImageBody(r,r.ImageModel,20);imageReq["images"]=1;imageReq["cfgscale"]=7;var baseImages=await Generate(imageReq,progress,ct);var bytes=await Download(baseImages[0],ct);input="data:image/png;base64,"+Convert.ToBase64String(bytes);}
            progress.Report(new(null,"Video wird vorbereitet …"));paths=await Generate(VideoBody(r,input),progress,ct);
        }else paths=await Generate(ImageBody(r),progress,ct);
        Directory.CreateDirectory(r.OutputFolder);var saved=new List<GalleryItem>();
        foreach(var url in paths) {
            ct.ThrowIfCancellationRequested();progress.Report(new(99,"Ergebnis wird auf diesem Gerät gespeichert …"));byte[] data=await Download(url,ct);string ext=r.Mode=="video"?".mp4":".png";
            string file=Path.Combine(r.OutputFolder,$"{DateTime.Now:yyyy-MM-dd_HH-mm-ss}_{r.Style}_{r.Id[..8]}_{saved.Count+1}{ext}"),temp=file+".part";
            try{await File.WriteAllBytesAsync(temp,data,ct);File.Move(temp,file,false);}finally{if(File.Exists(temp))File.Delete(temp);}
            var item=new GalleryItem{FilePath=file,Prompt=r.Prompt,Style=r.Style,Model=r.Model,Mode=r.Mode,Seed=r.Seed};GalleryStore.Save(item);saved.Add(item);
        }progress.Report(new(100,"Fertig · lokal gespeichert"));return saved;
    }
    public void Dispose()=>http.Dispose();
}
