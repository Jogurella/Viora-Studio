using System.Text.Json;
using System.Windows;
namespace SwarmStudio;
public partial class App : Application {
    protected override async void OnStartup(StartupEventArgs e) {
        base.OnStartup(e);
        if(e.Args.Contains("--selftest")){string folder=Argument(e.Args,"--output")??Path.Combine(Path.GetTempPath(),"VioraTests");Shutdown(await SelfTests.Run(folder));return;}
        if(e.Args.Contains("--smoke")) {
            string folder=Argument(e.Args,"--output")??Path.Combine(Path.GetTempPath(),"VioraSmoke");Directory.CreateDirectory(folder);
            try {
                using var client=new SwarmClient(Argument(e.Args,"--server")??"http://127.0.0.1:7801");await client.Connect();var models=await client.Models();bool video=e.Args.Contains("--video");var model=models.First(m=>video?m.Swap!=null:m.Swap==null);
                var r=new RenderRequest{Server="",Model=model.Name,SwapModel=model.Swap,ImageModel=models.First(m=>m.Swap==null).Name,Mode=video?"video":"image",Prompt="A small red cabin beside a calm alpine lake, cinematic morning light",Style="Realistisch",Width=256,Height=256,Steps=2,Frames=5,OutputFolder=folder,InputPath=Argument(e.Args,"--input")};
                var result=await client.Render(r,new Progress<RenderProgress>(),CancellationToken.None);await File.WriteAllTextAsync(Path.Combine(folder,"smoke-result.json"),JsonSerializer.Serialize(new{ok=true,results=result},AppSettings.JsonOptions));Shutdown(0);
            }catch(Exception ex){await File.WriteAllTextAsync(Path.Combine(folder,"smoke-result.json"),JsonSerializer.Serialize(new{ok=false,error=ex.ToString()},AppSettings.JsonOptions));Shutdown(1);}return;
        }
        DispatcherUnhandledException+=(_,a)=>{MessageBox.Show("Ein Fehler ist aufgetreten: "+a.Exception.Message,"Viora Studio");a.Handled=true;};
        new MainWindow().Show();
    }
    static string? Argument(string[] args,string key){int i=Array.IndexOf(args,key);return i>=0&&i+1<args.Length?args[i+1]:null;}
}
