using System.Diagnostics;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
namespace SwarmStudio;

public record ReleaseUpdate(string Version,string Download,string Checksums);
public static class Updates {
    public static System.Version CurrentVersion=>typeof(Updates).Assembly.GetName().Version??new System.Version(0,1,0);
    public static string VersionText=>CurrentVersion.ToString(3);
    static readonly HttpClient http=CreateHttp();
    static HttpClient CreateHttp(){var h=new HttpClient{Timeout=TimeSpan.FromMinutes(10)};h.DefaultRequestHeaders.UserAgent.ParseAdd("VioraStudio/"+VersionText);return h;}
    public static async Task<ReleaseUpdate?> Check(string repository) {
        if(!Regex.IsMatch(repository,@"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"))throw new ArgumentException("GitHub-Repository als Eigentümer/Name angeben.");
        using var response=await http.GetAsync("https://api.github.com/repos/"+repository+"/releases/latest");
        if(response.StatusCode==System.Net.HttpStatusCode.NotFound)throw new IOException("Für diesen Kanal ist noch kein öffentliches Release verfügbar. Prüfe den Repositorynamen.");response.EnsureSuccessStatusCode();
        var r=JsonNode.Parse(await response.Content.ReadAsStringAsync())!;string tag=r["tag_name"]?.ToString().TrimStart('v')??"";
        if(!System.Version.TryParse(tag,out var available))throw new IOException("Release hat keine gültige Versionsnummer.");
        if(available<=System.Version.Parse(VersionText))return null;
        string? zip=null,sums=null;
        foreach(var asset in r["assets"]?.AsArray()??[]){if(asset?["name"]?.ToString()=="VioraStudio-win-x64.zip")zip=asset["browser_download_url"]?.ToString();if(asset?["name"]?.ToString()=="SHA256SUMS.txt")sums=asset["browser_download_url"]?.ToString();}
        if(zip==null||sums==null)throw new IOException("Das Release enthält noch kein vollständiges Windows-Update mit Prüfsumme.");
        foreach(string url in new[]{zip,sums}){var u=new Uri(url);if(u.Scheme!="https"||u.Host!="github.com"||!u.AbsolutePath.StartsWith("/"+repository+"/releases/download/",StringComparison.Ordinal))throw new IOException("Ungültige Release-Adresse.");}
        return new(tag,zip,sums);
    }
    public static async Task<string> DownloadVerified(ReleaseUpdate update) {
        string root=Path.Combine(AppSettings.DataRoot,"Updates",Guid.NewGuid().ToString("N"));Directory.CreateDirectory(root);
        string sums=await http.GetStringAsync(update.Checksums);
        string zip=Path.Combine(root,"update.zip");
        using(var response=await http.GetAsync(update.Download,HttpCompletionOption.ResponseHeadersRead)){response.EnsureSuccessStatusCode();await using var source=await response.Content.ReadAsStreamAsync();await using var output=File.Create(zip);var buffer=new byte[65536];long total=0;int n;while((n=await source.ReadAsync(buffer))>0){total+=n;if(total>600L*1024*1024)throw new IOException("Update ist unerwartet groß.");await output.WriteAsync(buffer.AsMemory(0,n));}}
        string stage=Path.Combine(root,"files");await VerifyAndExtract(zip,sums,stage);
        await File.WriteAllTextAsync(Path.Combine(stage,"UPDATE LESEN.txt"),"Prüfsumme erfolgreich geprüft.\r\nViora Studio schließen. Die neue VioraStudio.exe in deinen bisherigen Programmordner kopieren und die alte Datei ersetzen. Danach VioraStudio.exe starten. Galerie und Einstellungen bleiben erhalten.\r\nBisheriger Programmordner: "+AppContext.BaseDirectory);
        return stage;
    }
    public static async Task VerifyAndExtract(string zip,string sums,string stage) {
        var match=Regex.Match(sums,@"(?im)^([a-f0-9]{64})\s+\*?VioraStudio-win-x64\.zip\s*$");if(!match.Success)throw new IOException("Für das Update ist keine gültige SHA-256-Prüfsumme vorhanden.");
        await using(var stream=File.OpenRead(zip)){string actual=Convert.ToHexString(await SHA256.HashDataAsync(stream));if(!actual.Equals(match.Groups[1].Value,StringComparison.OrdinalIgnoreCase))throw new IOException("Prüfsumme stimmt nicht. Das Update wird nicht ausgeführt.");}
        stage=Path.GetFullPath(stage);Directory.CreateDirectory(stage);
        using(var archive=ZipFile.OpenRead(zip)){if(archive.Entries.Count>2000)throw new IOException("Updatearchiv enthält zu viele Dateien.");long total=0;foreach(var entry in archive.Entries){total+=entry.Length;if(total>1200L*1024*1024)throw new IOException("Entpacktes Update zu groß.");string target=Path.GetFullPath(Path.Combine(stage,entry.FullName));if(!target.StartsWith(stage+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new IOException("Unsicherer Archivpfad.");if(entry.Name.Length==0){Directory.CreateDirectory(target);continue;}Directory.CreateDirectory(Path.GetDirectoryName(target)!);entry.ExtractToFile(target);}}
        if(!File.Exists(Path.Combine(stage,"VioraStudio.exe")))throw new IOException("Das Update enthält keine VioraStudio.exe.");
    }
}
