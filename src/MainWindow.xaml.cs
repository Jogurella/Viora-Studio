using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;

namespace SwarmStudio;
public partial class MainWindow : Window {
    readonly AppSettings settings=AppSettings.Load();
    readonly ObservableCollection<QueueItem> queue=[];
    readonly List<ModelChoice> models=[];
    GalleryItem? selectedResult;
    string? inputPath;
    bool processing,allowClose,queuePaused;
    CancellationTokenSource? currentCancel;
    SwarmClient? currentClient;
    QueueItem? active;
    static readonly string QueueFile=Path.Combine(AppSettings.DataRoot,"queue.json");
    public MainWindow() {
        InitializeComponent();QueueList.ItemsSource=queue;VersionLabel.Text="Viora Studio · Version "+Updates.VersionText;
        ServerBox.Text=settings.ServerUrl;FolderBox.Text=settings.GalleryFolder;RepositoryBox.Text=settings.UpdateRepository;
        FolderLabel.Text=string.IsNullOrEmpty(settings.GalleryFolder)?"Noch kein Galerieordner gewählt":settings.GalleryFolder;
        try {var old=JsonSerializer.Deserialize<List<QueueItem>>(File.ReadAllText(QueueFile));if(old!=null)foreach(var item in old.TakeLast(40)){if(item.Status=="Läuft")item.Status="Unterbrochen · nicht erneut gesendet";queue.Add(item);}}catch{}
        Loaded+=async(_,_)=>{RefreshGallery();if(settings.ServerUrl.Length>0)await ConnectServer(false);else SettingsPanel.Visibility=Visibility.Visible;};
        Closing+=async(_,e)=>{if(processing&&!allowClose){e.Cancel=true;if(MessageBox.Show(this,"Ein Auftrag läuft noch. Abbrechen und Viora Studio schließen? Mit Nein läuft die Berechnung weiter, solange die App geöffnet bleibt.","Auftrag läuft",MessageBoxButton.YesNo,MessageBoxImage.Question)==MessageBoxResult.Yes){await CancelCurrent();allowClose=true;Close();}}};
    }
    void SetStage(RenderProgress p) {
        StageLabel.Text=p.Stage;RenderBar.IsIndeterminate=p.Percent==null;if(p.Percent.HasValue)RenderBar.Value=p.Percent.Value;
        if(p.Preview?.StartsWith("data:image/",StringComparison.Ordinal)==true){try{byte[] b=Convert.FromBase64String(p.Preview[(p.Preview.IndexOf(',')+1)..]);using var s=new MemoryStream(b);var image=new BitmapImage();image.BeginInit();image.CacheOption=BitmapCacheOption.OnLoad;image.StreamSource=s;image.EndInit();ResultImage.Source=image;ResultImage.Visibility=Visibility.Visible;ResultVideo.Visibility=Visibility.Collapsed;EmptyPreview.Visibility=Visibility.Collapsed;}catch{}}
    }
    void PersistQueue(){try{Directory.CreateDirectory(AppSettings.DataRoot);AppSettings.AtomicWrite(QueueFile,JsonSerializer.Serialize(queue,AppSettings.JsonOptions));}catch(Exception e){StageLabel.Text="Warteschlange konnte nicht gespeichert werden: "+e.Message;}}
    async Task ConnectServer(bool showError) {
        SettingsStatus.Text="Verbindung wird geprüft …";ConnectionLabel.Text="● Verbinde …";
        try {
            using var client=new SwarmClient(ServerBox.Text);using var timeout=new CancellationTokenSource(TimeSpan.FromSeconds(20));
            await client.Connect(timeout.Token);var found=await client.Models(timeout.Token);
            if(!found.Any())throw new IOException("Keine unterstützten SDXL- oder Wan-Modelle gefunden.");
            models.Clear();models.AddRange(found);settings.ServerUrl=ServerBox.Text.Trim().TrimEnd('/');settings.GalleryFolder=FolderBox.Text;settings.UpdateRepository=RepositoryBox.Text.Trim();settings.Save();
            UpdateModelPicker();ConnectionLabel.Text="● Server verbunden";ConnectionLabel.Foreground=new SolidColorBrush(Color.FromRgb(114,221,182));SettingsStatus.Text="Verbunden · "+found.Count+" Modelloptionen verfügbar.";
            StageLabel.Text="Bereit. Dein Server übernimmt die KI-Berechnung.";FolderLabel.Text=settings.GalleryFolder.Length>0?settings.GalleryFolder:"Galerieordner in Einstellungen wählen";RefreshGallery();
            if(showError&&settings.GalleryFolder.Length>0)SettingsPanel.Visibility=Visibility.Collapsed;
        }catch(Exception e){ConnectionLabel.Text="● Nicht verbunden";ConnectionLabel.Foreground=new SolidColorBrush(Color.FromRgb(224,158,175));SettingsStatus.Text=FriendlyError(e);if(showError)MessageBox.Show(this,SettingsStatus.Text,"Verbindung",MessageBoxButton.OK,MessageBoxImage.Information);}
    }
    static string FriendlyError(Exception e)=>e is OperationCanceledException?"Der Server antwortet nicht. Prüfe Tailscale, die Adresse und ob SwarmUI auf dem Server läuft.":e.Message;
    void UpdateModelPicker(){if(ModelPicker==null)return;bool video=VideoMode.IsChecked==true;var filtered=models.Where(m=>video?m.Swap!=null:m.Swap==null).ToList();ModelPicker.ItemsSource=filtered;if(filtered.Count>0)ModelPicker.SelectedIndex=0;}
    void ModeChanged(object sender,RoutedEventArgs e){if(!IsInitialized)return;bool video=VideoMode.IsChecked==true;InputPanel.Visibility=video?Visibility.Visible:Visibility.Collapsed;QuantityPicker.Visibility=video?Visibility.Collapsed:Visibility.Visible;DurationPicker.Visibility=video?Visibility.Visible:Visibility.Collapsed;QuantityTitle.Text=video?"LÄNGE":"ANZAHL";GenerateButton.Content=video?"✦  Video generieren":"✦  Bild generieren";UpdateModelPicker();}
    void StudioClick(object sender,RoutedEventArgs e){GalleryPanel.Visibility=Visibility.Collapsed;StudioPanel.Visibility=Visibility.Visible;}
    void GalleryClick(object sender,RoutedEventArgs e){StudioPanel.Visibility=Visibility.Collapsed;GalleryPanel.Visibility=Visibility.Visible;RefreshGallery();}
    void QueueClick(object sender,RoutedEventArgs e){StudioClick(sender,e);QueueList.Focus();}
    void SettingsClick(object sender,RoutedEventArgs e){SettingsPanel.Visibility=Visibility.Visible;}
    void CloseSettingsClick(object sender,RoutedEventArgs e){SettingsPanel.Visibility=Visibility.Collapsed;}
    async void ConnectClick(object sender,RoutedEventArgs e){await ConnectServer(true);}
    void ChooseFolderClick(object sender,RoutedEventArgs e){var dialog=new OpenFolderDialog{Title="Galerieordner auswählen oder neu anlegen",Multiselect=false};if(Directory.Exists(FolderBox.Text))dialog.InitialDirectory=FolderBox.Text;if(dialog.ShowDialog(this)==true){FolderBox.Text=dialog.FolderName;settings.GalleryFolder=dialog.FolderName;settings.Save();FolderLabel.Text=dialog.FolderName;RefreshGallery();}}
    void OpenFolderClick(object sender,RoutedEventArgs e){if(Directory.Exists(settings.GalleryFolder))OpenShell(settings.GalleryFolder);else{SettingsPanel.Visibility=Visibility.Visible;ChooseFolderClick(sender,e);}}
    void PickInputClick(object sender,RoutedEventArgs e){var d=new OpenFileDialog{Filter="Bilder|*.png;*.jpg;*.jpeg;*.bmp",Title="Startbild wählen"};if(d.ShowDialog(this)==true){inputPath=d.FileName;InputLabel.Text=Path.GetFileName(inputPath);ClearInput.Visibility=Visibility.Visible;}}
    void ClearInputClick(object sender,RoutedEventArgs e){inputPath=null;InputLabel.Text="Ohne Upload wird zuerst ein Startbild erzeugt.";ClearInput.Visibility=Visibility.Collapsed;}
    async void GenerateClick(object sender,RoutedEventArgs e) {
        try {
            if(PromptBox.Text.Trim().Length==0)throw new ArgumentException("Beschreibe zuerst, was entstehen soll.");
            if(PromptBox.Text.Length>12000)throw new ArgumentException("Bitte kürze die Beschreibung auf maximal 12.000 Zeichen.");
            if(settings.ServerUrl.Length==0||models.Count==0){SettingsPanel.Visibility=Visibility.Visible;throw new ArgumentException("Bitte zuerst mit dem KI-Server verbinden.");}
            if(settings.GalleryFolder.Length==0){ChooseFolderClick(sender,e);if(settings.GalleryFolder.Length==0)return;}
            if(queue.Count(x=>x.Status=="Wartet"||x.Status=="Läuft")>=6)throw new ArgumentException("Es sind bereits sechs Aufträge vorgemerkt. Warte, bis ein Auftrag fertig ist.");
            if(ModelPicker.SelectedItem is not ModelChoice model)throw new ArgumentException("Bitte ein unterstütztes Modell auswählen.");
            bool video=VideoMode.IsChecked==true;int quality=QualityPicker.SelectedIndex;string ratio=(AspectPicker.SelectedItem as ComboBoxItem)?.Tag?.ToString()??"square";
            (int w,int h)=video?ratio switch{"portrait"=>(288,512),"landscape"=>(512,288),_=>(512,512)}:ratio switch{"portrait"=>(576,1024),"landscape"=>(1024,576),_=>(768,768)};
            if(!long.TryParse(SeedBox.Text,out long seed)||seed< -1)throw new ArgumentException("Seed muss -1 oder eine positive ganze Zahl sein.");if(seed==-1)seed=System.Security.Cryptography.RandomNumberGenerator.GetInt32(1,int.MaxValue);
            var r=new RenderRequest{Server=settings.ServerUrl,Mode=video?"video":"image",Prompt=PromptBox.Text.Trim(),Negative=NegativeBox.Text,Style=AnimeStyle.IsChecked==true?"Anime":AnimationStyle.IsChecked==true?"Animation":"Realistisch",Model=model.Name,SwapModel=model.Swap,ImageModel=models.FirstOrDefault(x=>x.Swap==null)?.Name??"",Width=w,Height=h,Steps=video?new[]{12,20,30}[quality]:new[]{12,25,35}[quality],Cfg=video?3.5:7,Frames=int.Parse((DurationPicker.SelectedItem as ComboBoxItem)?.Tag?.ToString()??"49"),Count=video?1:int.Parse((QuantityPicker.SelectedItem as ComboBoxItem)?.Tag?.ToString()??"1"),Seed=seed,OutputFolder=settings.GalleryFolder};
            if(video&&r.ImageModel.Length==0)throw new ArgumentException("Für diesen Videoablauf wird zusätzlich ein SDXL-Bildmodell benötigt.");
            if(video&&inputPath!=null){string folder=Path.Combine(AppSettings.DataRoot,"Inputs");Directory.CreateDirectory(folder);string snapshot=Path.Combine(folder,r.Id+Path.GetExtension(inputPath));if(new FileInfo(inputPath).Length>30*1024*1024)throw new ArgumentException("Das Startbild ist größer als 30 MB.");File.Copy(inputPath,snapshot);r.InputPath=snapshot;}
            var item=new QueueItem{Request=r};queue.Add(item);QueueList.SelectedItem=item;PersistQueue();queuePaused=false;await ProcessQueue();
        }catch(Exception ex){MessageBox.Show(this,FriendlyError(ex),"Viora Studio",MessageBoxButton.OK,MessageBoxImage.Information);}
    }
    async Task ProcessQueue() {
        if(processing)return;processing=true;
        try{while(!queuePaused&&queue.FirstOrDefault(x=>x.Status=="Wartet") is QueueItem item){active=item;item.Status="Läuft";PersistQueue();currentCancel=new();using var client=new SwarmClient(item.Request.Server);currentClient=client;
            try{ResultVideo.Stop();SetStage(new(null,"Verbindung und Modell werden vorbereitet …"));ResultTag.Text="BERECHNUNG AUF DEINEM SERVER";var results=await client.Render(item.Request,new Progress<RenderProgress>(SetStage),currentCancel.Token);item.Status="Fertig · lokal gespeichert";RefreshGallery();if(results.Count>0)ShowResult(results.Last());}
            catch(OperationCanceledException){item.Status="Abgebrochen";SetStage(new(0,"Auftrag abgebrochen."));}
            catch(Exception e){item.Status="Fehler · "+FriendlyError(e);SetStage(new(0,FriendlyError(e)));}
            finally{currentClient=null;currentCancel.Dispose();currentCancel=null;PersistQueue();}
        }}finally{processing=false;active=null;}
    }
    async Task CancelCurrent(){queuePaused=true;var cancel=currentCancel;try{using var timeout=new CancellationTokenSource(TimeSpan.FromSeconds(4));if(currentClient!=null)await currentClient.Interrupt(timeout.Token);}catch{SettingsStatus.Text="Der Server hat den Abbruch nicht bestätigt. Prüfe den Server, bevor du erneut startest.";}finally{if(ReferenceEquals(cancel,currentCancel))cancel?.Cancel();}}
    async void CancelClick(object sender,RoutedEventArgs e){await CancelCurrent();}
    void RemoveQueuedClick(object sender,RoutedEventArgs e){if(QueueList.SelectedItem is QueueItem q&&q!=active){queue.Remove(q);PersistQueue();}}
    async void ResumeQueueClick(object sender,RoutedEventArgs e){queuePaused=false;await ProcessQueue();}
    void RefreshGallery(){if(GalleryList==null)return;var entries=GalleryStore.Read(settings.GalleryFolder);entries=GalleryFilter?.SelectedIndex switch{1=>entries.Where(x=>x.Mode=="image"),2=>entries.Where(x=>x.Mode=="video"),3=>entries.Where(x=>x.Favorite),_=>entries};GalleryList.ItemsSource=entries.ToList();}
    void FilterChanged(object sender,SelectionChangedEventArgs e){if(IsInitialized)RefreshGallery();}
    void GalleryDoubleClick(object sender,System.Windows.Input.MouseButtonEventArgs e){if(GalleryList.SelectedItem is GalleryItem g){StudioPanel.Visibility=Visibility.Visible;GalleryPanel.Visibility=Visibility.Collapsed;ShowResult(g);}}
    void ShowResult(GalleryItem item){selectedResult=item;ResultVideo.Stop();EmptyPreview.Visibility=Visibility.Collapsed;ResultTag.Text=item.Label;
        if(item.Mode=="video"){ResultImage.Visibility=Visibility.Collapsed;ResultVideo.Visibility=Visibility.Visible;ResultVideo.Source=new Uri(item.FilePath);ResultVideo.Play();}else{ResultVideo.Visibility=Visibility.Collapsed;ResultImage.Visibility=Visibility.Visible;var image=new BitmapImage();image.BeginInit();image.CacheOption=BitmapCacheOption.OnLoad;image.UriSource=new Uri(item.FilePath);image.EndInit();ResultImage.Source=image;}
        StageLabel.Text="Gespeichert: "+Path.GetFileName(item.FilePath);RenderBar.IsIndeterminate=false;RenderBar.Value=100;
    }
    void VideoEnded(object sender,RoutedEventArgs e){ResultVideo.Position=TimeSpan.Zero;ResultVideo.Play();}
    void VideoFailed(object sender,ExceptionRoutedEventArgs e){StageLabel.Text="Die Windows-Videovorschau ist nicht verfügbar. Die MP4 ist gespeichert und kann über Datei öffnen abgespielt werden.";}
    static void OpenShell(string path){try{Process.Start(new ProcessStartInfo(path){UseShellExecute=true});}catch{}}
    void OpenResultClick(object sender,RoutedEventArgs e){if(selectedResult!=null)OpenShell(selectedResult.FilePath);}
    void SaveAsClick(object sender,RoutedEventArgs e){if(selectedResult==null)return;var d=new SaveFileDialog{FileName=Path.GetFileName(selectedResult.FilePath),Filter=selectedResult.Mode=="video"?"MP4-Video|*.mp4":"PNG-Bild|*.png",OverwritePrompt=true};if(d.ShowDialog(this)==true){try{if(Path.GetFullPath(d.FileName)!=Path.GetFullPath(selectedResult.FilePath))File.Copy(selectedResult.FilePath,d.FileName,true);}catch(Exception ex){MessageBox.Show(this,ex.Message,"Speichern");}}}
    void ToVideoClick(object sender,RoutedEventArgs e){if(selectedResult?.Mode!="image")return;inputPath=selectedResult.FilePath;VideoMode.IsChecked=true;InputLabel.Text=Path.GetFileName(inputPath);ClearInput.Visibility=Visibility.Visible;PromptBox.Text=selectedResult.Prompt;}
    void FavoriteClick(object sender,RoutedEventArgs e){if(selectedResult==null)return;selectedResult.Favorite=!selectedResult.Favorite;GalleryStore.Save(selectedResult);RefreshGallery();StageLabel.Text=selectedResult.Favorite?"Zu Favoriten hinzugefügt.":"Aus Favoriten entfernt.";}
    async void UpdateClick(object sender,RoutedEventArgs e){try{SettingsStatus.Text="GitHub Releases wird geprüft …";var update=await Updates.Check(RepositoryBox.Text.Trim());if(update==null){SettingsStatus.Text="Du verwendest die aktuelle Version. Noch nicht veröffentlichte Releases werden nicht angeboten.";return;}if(MessageBox.Show(this,$"Version {update.Version} ist verfügbar. Update herunterladen und Prüfsumme prüfen? Galerie und Einstellungen bleiben erhalten.","Viora Studio Update",MessageBoxButton.YesNo,MessageBoxImage.Question)==MessageBoxResult.Yes){if(processing)throw new IOException("Bitte zuerst den laufenden Auftrag abschließen lassen.");SettingsStatus.Text="Update wird geladen …";string folder=await Updates.DownloadVerified(update);SettingsStatus.Text="Update geprüft. App schließen und die neue EXE in den bisherigen Programmordner kopieren.";OpenShell(folder);MessageBox.Show(this,"Das Update wurde heruntergeladen und geprüft. Schließe Viora Studio und kopiere die neue VioraStudio.exe aus dem geöffneten Ordner über die bisherige App-Datei. Galerie und Einstellungen bleiben erhalten.","Update bereit");}}catch(Exception ex){SettingsStatus.Text=ex.Message;}}
}


