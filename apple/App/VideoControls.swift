import SwiftUI
import UniformTypeIdentifiers

struct VideoSourceControls: View {
    @Bindable var studio: StudioModel
    @State private var showGallery = false
    @State private var importing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var images: [GalleryEntry] { studio.gallery.filter { $0.mediaType == "image" } }
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Label(studio.draft.initImage == nil ? "Ausgangsbild wählen" : studio.videoSourceID != nil ? "Dein generiertes Bild ist übernommen" : "Dein Ausgangsbild ist bereit",systemImage:studio.draft.initImage == nil ? "photo" : "checkmark.circle.fill")
                .font(VioraTheme.text(12,.semibold)).foregroundStyle(studio.draft.initImage == nil ? .secondary : VioraTheme.cyan)
                .accessibilityIdentifier("videoSourceStatus")
            HStack(spacing:8) {
                if studio.recentImage != nil {
                    Button { studio.useGeneratedImage() } label: { Label("Letztes Bild",systemImage:"arrow.uturn.backward").frame(maxWidth:.infinity,minHeight:44) }
                        .accessibilityIdentifier("useGeneratedImage")
                }
                Button { withAnimation(reduceMotion ? nil : .easeInOut(duration:0.25)) {showGallery.toggle()} } label: { Label("Galerie",systemImage:"square.grid.2x2").frame(maxWidth:.infinity,minHeight:44) }
                    .disabled(images.isEmpty)
                Button {importing=true} label: {Image(systemName:"folder.badge.plus").frame(width:44,height:44)}.accessibilityLabel("Bild importieren")
            }.font(VioraTheme.text(12,.semibold)).buttonStyle(.plain).vioraGlass(14,soft:true)
            if showGallery {
                ScrollView(.horizontal) {
                    HStack(spacing:10) {
                        ForEach(images) {entry in
                            Button {studio.useGeneratedImage(entry);showGallery=false} label: {
                                Group {if let url=studio.mediaURL(entry) {MediaThumbnail(url:url,video:false)}}
                                    .frame(width:80,height:80).clipped().clipShape(RoundedRectangle(cornerRadius:14))
                                    .overlay(RoundedRectangle(cornerRadius:14).strokeBorder(studio.videoSourceID == entry.id ? VioraTheme.cyan : .white.opacity(0.15),lineWidth:2))
                            }.buttonStyle(GeneratePressStyle()).accessibilityLabel("Dieses Bild verwenden: \(entry.request.prompt)")
                        }
                    }.padding(.vertical,2)
                }.scrollIndicators(.hidden)
            }
        }.fileImporter(isPresented:$importing,allowedContentTypes:[.image]) { result in
            do {studio.importImage(try result.get())} catch {studio.report(error)}
        }
    }
}

struct InlineVideoOptions: View {
    @Bindable var studio: StudioModel
    let section: OptionSection
    let close: () -> Void
    private var frameRates: [Int] {
        let spec=studio.specs.first {$0.id == "videofps"}
        return [8,16,24,25,30,48,50,60,120].filter { Double($0) >= (spec?.min ?? 1) && Double($0) <= (spec?.max ?? 120) }
    }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                FieldLabel(text:section == .quantity ? "Video-Einstellungen" : section == .models ? "Video-Modell" : "Weitere Video-Optionen")
                Spacer()
                Button(action:close) {Image(systemName:"chevron.up").frame(width:44,height:44)}.buttonStyle(.plain).accessibilityLabel("Video-Einstellungen einklappen")
            }.frame(height:24)
            if section == .models {
                modelPicker("HighNoise",selection:$studio.draft.videoModel,models:studio.models.filter(\.isVideo))
                modelPicker("LowNoise",selection:$studio.draft.swapModel,models:studio.models.filter(\.isVideo))
                Text("Beide Modelle werden für das Video gemeinsam verwendet.").font(VioraTheme.text(12)).foregroundStyle(.secondary)
                if studio.models.isEmpty {Text("Oben über „Verbinden“ den Server koppeln, um Modelle zu laden.").font(VioraTheme.text(12)).foregroundStyle(.orange)}
            } else if section == .quantity {
                VStack(alignment:.leading,spacing:8) {
                    HStack {Text("Dauer");Spacer();Text(String(format:"%.2f s",Double(studio.draft.frames)/Double(studio.draft.fps))).font(VioraTheme.mono(13))}
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:64))],spacing:8) {
                        ForEach([1,3,5,10,15,30,60],id:\.self) {seconds in
                            Button {studio.setVideoDuration(Double(seconds))} label: {
                                Text("\(seconds) s").font(VioraTheme.mono(12))
                                    .frame(maxWidth:.infinity,minHeight:44)
                                    .background(abs(studio.videoDuration-Double(seconds)) < 0.15 ? VioraTheme.violet.opacity(0.35) : .white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
                            }.buttonStyle(.plain).accessibilityAddTraits(abs(studio.videoDuration-Double(seconds)) < 0.15 ? [.isSelected] : [])
                        }
                    }
                    Stepper("Dauer fein einstellen",value:Binding(get:{Int(studio.videoDuration.rounded())},set:{studio.setVideoDuration(Double($0))}),in:1...60).frame(minHeight:44)
                }
                VStack(alignment:.leading,spacing:8) {
                    Text("Bildrate").font(VioraTheme.text(13,.semibold))
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:72))],spacing:8) {
                        ForEach(frameRates,id:\.self) {fps in
                            Button {studio.setVideoFPS(fps)} label: {
                                Text("\(fps) FPS").font(VioraTheme.mono(12)).frame(maxWidth:.infinity,minHeight:44)
                                    .background(studio.draft.fps == fps ? VioraTheme.violet.opacity(0.35) : .white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
                            }.buttonStyle(.plain).accessibilityAddTraits(studio.draft.fps == fps ? [.isSelected] : [])
                        }
                    }
                    Text("Die gewählte Dauer bleibt erhalten. Mehr FPS erzeugen mehr Frames und benötigen mehr Rechenzeit.").font(VioraTheme.text(11)).foregroundStyle(.secondary)
                }
                Stepper("Qualität: \(studio.draft.steps) Schritte",value:$studio.draft.steps,in:1...80).frame(minHeight:44)
                Stepper("Anzahl: \(studio.draft.count)",value:$studio.draft.count,in:1...4).frame(minHeight:44)
                if let plan=try? VideoPlan(frames:studio.draft.frames,fps:studio.draft.fps),plan.segments.count > 1 {
                    Text("Längere Videos entstehen in \(plan.segments.count) verbundenen Abschnitten. Übergänge können sichtbar sein; lange Clips können deutlich länger rechnen.").font(VioraTheme.text(12)).foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment:.leading,spacing:8) {
                    FieldLabel(text:"Negativ-Prompt")
                    TextField("Was soll vermieden werden?",text:$studio.draft.negative,axis:.vertical).lineLimit(2...4).autocorrectionDisabled().padding(12).vioraGlass(14,soft:true)
                }
                HStack {Text("CFG");Slider(value:$studio.draft.cfg,in:1...20,step:0.5);Text(studio.draft.cfg,format:.number.precision(.fractionLength(1))).font(VioraTheme.mono(12))}
                HStack {Text("Seed");TextField("−1 = zufällig",value:$studio.draft.seed,format:.number.grouping(.never)).font(VioraTheme.mono(13)).multilineTextAlignment(.trailing).padding(10).vioraGlass(12,soft:true)}
                parameterPicker("Sampler",key:"sampler",selection:$studio.draft.sampler)
                parameterPicker("Scheduler",key:"scheduler",selection:$studio.draft.scheduler)
                Picker("Stil",selection:$studio.draft.style) {ForEach(VisualStyle.allCases,id:\.self){Text($0.rawValue).tag($0)}}.pickerStyle(.menu)
                    .onChange(of:studio.draft.style) {_,style in studio.draft.styleSuffix=style.suffix}
                TextField("Stilzusatz",text:$studio.draft.styleSuffix,axis:.vertical).lineLimit(2...4).autocorrectionDisabled().padding(12).vioraGlass(14,soft:true)
            }
        }.font(VioraTheme.text(13)).padding(14).vioraGlass(20,soft:true).accessibilityIdentifier("inlineVideoSettings")
    }
    func modelPicker(_ label:String,selection:Binding<String>,models:[SwarmModel]) -> some View {
        VStack(alignment:.leading,spacing:4) {
            FieldLabel(text:label)
            Picker(label,selection:selection) {Text("Auswählen").tag("");ForEach(models){Text($0.name).tag($0.name)}}
                .labelsHidden().pickerStyle(.menu).frame(maxWidth:.infinity,minHeight:44,alignment:.leading)
        }
    }
    func parameterPicker(_ title:String,key:String,selection:Binding<String>) -> some View {
        Picker(title,selection:selection) {ForEach(studio.specs.first{$0.id == key}?.values ?? [selection.wrappedValue],id:\.self){Text($0).tag($0)}}.pickerStyle(.menu).frame(minHeight:44)
    }
}

struct StyleSelection: View {
    @Bindable var studio: StudioModel
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Button {dismissKeyboard();withAnimation(reduceMotion ? nil : .easeInOut(duration:0.25)) {expanded.toggle()}} label: {
                HStack(spacing:10) {
                    Image(systemName:"paintpalette").foregroundStyle(VioraTheme.violet)
                    Text("Stil").font(VioraTheme.text(12,.semibold)).foregroundStyle(.secondary)
                    Text(studio.draft.style.rawValue).font(VioraTheme.text(13,.bold))
                    Spacer()
                    Text("\(VisualStyle.allCases.count)").font(VioraTheme.mono(11)).foregroundStyle(.secondary)
                    Image(systemName:expanded ? "chevron.up" : "chevron.down").font(.system(size:12,weight:.semibold))
                }.frame(minHeight:44)
            }.buttonStyle(.plain).accessibilityIdentifier("styleSelection")
            if expanded {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:96))],spacing:8) {
                    ForEach(VisualStyle.allCases,id:\.self) {style in
                        Button {studio.draft.style=style;studio.draft.styleSuffix=style.suffix} label: {
                            Text(style.rawValue).font(VioraTheme.text(12,.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                .frame(maxWidth:.infinity,minHeight:44)
                                .background(studio.draft.style == style ? VioraTheme.violet.opacity(0.35) : .white.opacity(0.06),in:RoundedRectangle(cornerRadius:12))
                                .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(studio.draft.style == style ? VioraTheme.violet : .white.opacity(0.1)))
                        }.buttonStyle(GeneratePressStyle()).accessibilityAddTraits(studio.draft.style == style ? [.isSelected] : [])
                    }
                }
                Text("Der Stil ergänzt deinen Prompt. Das Ergebnis hängt auch vom Modell und beim Video vom Ausgangsbild ab.").font(VioraTheme.text(11)).foregroundStyle(.secondary)
            }
        }.padding(.horizontal,12).padding(.vertical,4).vioraGlass(16,soft:true)
    }
}
