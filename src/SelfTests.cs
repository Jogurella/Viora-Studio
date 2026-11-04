using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;
namespace SwarmStudio;
public static class SelfTests {
    public static async Task<int> Run(string folder) {
        Directory.CreateDirectory(folder);var checks=new List<string>();
        try {
            foreach(string address in new[]{"http://example.com","https://user:pass@example.com","https://example.com/secret"}) {bool rejected=false;try{using var client=new SwarmClient(address);}catch(ArgumentException){rejected=true;}if(!rejected)throw new Exception("URL accepted: "+address);}checks.Add("Remote HTTP, credentials and subpaths rejected");
            using(var client=new SwarmClient("https://example.com:8443")){}checks.Add("HTTPS custom port accepted");
            string CreateZip(string name,string entry){string path=Path.Combine(folder,name+".zip");using var z=ZipFile.Open(path,ZipArchiveMode.Create);using var w=new StreamWriter(z.CreateEntry(entry).Open());w.Write("test fixture, never executable");return path;}
            string Sums(string path)=>Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)))+"  VioraStudio-win-x64.zip";
            string good=CreateZip(Guid.NewGuid().ToString("N"),"VioraStudio.exe");
            await Updates.VerifyAndExtract(good,Sums(good),Path.Combine(folder,Guid.NewGuid().ToString("N")));checks.Add("Valid checksum and root executable accepted");
            bool corrupt=false;try{await Updates.VerifyAndExtract(good,new string('0',64)+"  VioraStudio-win-x64.zip",Path.Combine(folder,Guid.NewGuid().ToString("N")));}catch(IOException){corrupt=true;}if(!corrupt)throw new Exception("Bad checksum accepted");checks.Add("Corrupt package rejected");
            string bad=CreateZip(Guid.NewGuid().ToString("N"),"../outside.txt");bool traversal=false;try{await Updates.VerifyAndExtract(bad,Sums(bad),Path.Combine(folder,Guid.NewGuid().ToString("N")));}catch(IOException){traversal=true;}if(!traversal||File.Exists(Path.Combine(folder,"outside.txt")))throw new Exception("Unsafe archive accepted");checks.Add("Archive path traversal rejected");
            string missing=CreateZip(Guid.NewGuid().ToString("N"),"README.txt");bool absent=false;try{await Updates.VerifyAndExtract(missing,Sums(missing),Path.Combine(folder,Guid.NewGuid().ToString("N")));}catch(IOException){absent=true;}if(!absent)throw new Exception("Missing executable accepted");checks.Add("Incomplete update rejected");
            await File.WriteAllTextAsync(Path.Combine(folder,"selftest-result.json"),JsonSerializer.Serialize(new{ok=true,checks},AppSettings.JsonOptions));return 0;
        }catch(Exception ex){await File.WriteAllTextAsync(Path.Combine(folder,"selftest-result.json"),JsonSerializer.Serialize(new{ok=false,checks,error=ex.ToString()},AppSettings.JsonOptions));return 1;}
    }
}
