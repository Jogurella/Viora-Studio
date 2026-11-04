using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Security.Cryptography;

namespace SwarmStudio;

public class Observable : INotifyPropertyChanged {
    public event PropertyChangedEventHandler? PropertyChanged;
    protected void Set<T>(ref T field,T value,[CallerMemberName]string name="") { field=value; PropertyChanged?.Invoke(this,new(name)); }
}
public record ModelChoice(string Name,string Label,string Architecture,string? Swap=null) { public override string ToString()=>Label; }
public record RenderProgress(double? Percent,string Stage,string? Preview=null);
public class RenderRequest {
    public string Id {get;set;}=Guid.NewGuid().ToString("N");
    public string Server {get;set;}="";
    public string Mode {get;set;}="image";
    public string Prompt {get;set;}="";
    public string Negative {get;set;}="blurry, low quality, watermark, distorted anatomy";
    public string Style {get;set;}="Realistisch";
    public string Model {get;set;}="";
    public string? SwapModel {get;set;}
    public string ImageModel {get;set;}="";
    public int Width {get;set;}=768;
    public int Height {get;set;}=768;
    public int Steps {get;set;}=25;
    public double Cfg {get;set;}=7;
    public int Frames {get;set;}=49;
    public int Count {get;set;}=1;
    public long Seed {get;set;}=RandomNumberGenerator.GetInt32(1,int.MaxValue);
    public string? InputPath {get;set;}
    public string OutputFolder {get;set;}="";
    public string StyledPrompt=>Prompt.Trim()+(Style switch {
        "Anime"=>", anime illustration, expressive character design, clean line art, cel shading, detailed background, coherent composition",
        "Animation"=>", stylized 3D animated film, expressive design, soft cinematic lighting, rich colors, polished materials",
        _=>", photorealistic, natural lighting, detailed textures, cinematic photography"
    });
}
public class QueueItem : Observable {
    public RenderRequest Request {get;set;}=new();
    private string status="Wartet";
    public string Status {get=>status;set=>Set(ref status,value);}
    public string Title=>Request.Prompt;
    public string Detail=>$"{(Request.Mode=="video"?"Video":"Bild")} · {Request.Style} · {Request.Width} × {Request.Height}";
    public bool Pending=>Status=="Wartet";
}
public class GalleryItem {
    public string FilePath {get;set;}="";
    public string Prompt {get;set;}="";
    public string Style {get;set;}="";
    public string Model {get;set;}="";
    public string Mode {get;set;}="image";
    public long Seed {get;set;}
    public DateTime Created {get;set;}=DateTime.Now;
    public bool Favorite {get;set;}
    public string Label=>$"{(Mode=="video"?"▶ VIDEO":"BILD")} · {Style}";
    public string Title=>Prompt.Length>90?Prompt[..90]+"…":Prompt;
    public string Time=>Created.ToString("dd.MM. HH:mm");
    public string Icon=>Mode=="video"?"▶":"▧";
}
public class AppSettings {
    public string ServerUrl {get;set;}="";
    public string GalleryFolder {get;set;}="";
    public string UpdateRepository {get;set;}="Jogurella/Viora-Studio";
    public static string DataRoot=>Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"VioraStudio");
    public static JsonSerializerOptions JsonOptions=new(){WriteIndented=true};
    public static AppSettings Load() { try {return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(Path.Combine(DataRoot,"settings.json")))??new();}catch{return new();} }
    public void Save(){Directory.CreateDirectory(DataRoot); AtomicWrite(Path.Combine(DataRoot,"settings.json"),JsonSerializer.Serialize(this,JsonOptions));}
    public static void AtomicWrite(string path,string content){File.WriteAllText(path+".tmp",content);File.Move(path+".tmp",path,true);}
}
public static class GalleryStore {
    public static IEnumerable<GalleryItem> Read(string folder) {
        if(!Directory.Exists(folder))return [];
        var items=new List<GalleryItem>();
        foreach(var f in Directory.EnumerateFiles(folder,"*.swarm.json")) {try{var item=JsonSerializer.Deserialize<GalleryItem>(File.ReadAllText(f)); if(item!=null&&File.Exists(item.FilePath))items.Add(item);}catch{}}
        return items.OrderByDescending(x=>x.Created);
    }
    public static void Save(GalleryItem item)=>AppSettings.AtomicWrite(item.FilePath+".swarm.json",JsonSerializer.Serialize(item,AppSettings.JsonOptions));
}
