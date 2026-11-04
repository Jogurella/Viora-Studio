import SwiftUI
import AVKit
import UniformTypeIdentifiers
import ImageIO
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum VioraTheme {
    static let background = Color(red: 6/255, green: 7/255, blue: 11/255)
    static let violet = Color(red: 139/255, green: 123/255, blue: 1)
    static let purple = Color(red: 109/255, green: 76/255, blue: 1)
    static let cyan = Color(red: 20/255, green: 184/255, blue: 212/255)
    static let pink = Color(red: 1, green: 92/255, blue: 138/255)
    static let gradient = LinearGradient(colors: [violet, purple, Color(red: 224/255, green: 86/255, blue: 155/255)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static func text(_ size: CGFloat = 14, _ weight: Font.Weight = .medium) -> Font { .custom("Manrope-Regular", size: size, relativeTo: .body).weight(weight) }
    static func title(_ size: CGFloat = 28) -> Font { .custom("SpaceGrotesk-Light_Bold", size: size, relativeTo: .title) }
    static func mono(_ size: CGFloat = 13) -> Font { .custom("JetBrainsMono-Regular", size: size, relativeTo: .caption) }
}
struct StudioBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1/30, paused: reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                let first = reduceMotion ? 0 : (1 - cos(t * .pi / 9)) / 2
                let second = reduceMotion ? 0 : (1 - cos(t * .pi / 12)) / 2
                ZStack(alignment: .topLeading) {
                    Circle().fill(VioraTheme.purple).frame(width:340,height:340).scaleEffect(1 + first * 0.15).offset(x:-120 + first * 60,y:-60 + first * 70)
                    Circle().fill(VioraTheme.cyan).frame(width:300,height:300).scaleEffect(1 - second * 0.1).offset(x:geometry.size.width - 180 - second * 70,y:300 - second * 40)
                    Circle().fill(VioraTheme.pink).frame(width:260,height:260).scaleEffect(1 + first * 0.15).offset(x:40 + first * 60,y:geometry.size.height - 180 + first * 30)
                }.frame(width:geometry.size.width,height:geometry.size.height,alignment:.topLeading).blur(radius:70).opacity(0.55)
            }.background(VioraTheme.background)
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
struct VioraEntrance: ViewModifier {
    var delay: Double = 0
    var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    func body(content: Content) -> some View {
        content.opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 16)
            .scaleEffect(appeared || reduceMotion || !pop ? 1 : 0.92)
            .task {
                await Task.yield()
                withAnimation(reduceMotion ? nil : .timingCurve(0.2,0.8,0.2,1,duration:0.7).delay(delay)) { appeared = true }
            }
    }
}
extension View {
    func vioraEntrance(_ delay: Double = 0, pop: Bool = false) -> some View { modifier(VioraEntrance(delay:delay,pop:pop)) }
}
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 20
    var soft = false
    func body(content: Content) -> some View {
        content.background {
            ZStack {
                if !soft { RoundedRectangle(cornerRadius: radius).fill(.ultraThinMaterial).opacity(0.55) }
                RoundedRectangle(cornerRadius: radius).fill(.white.opacity(soft ? 0.055 : 0.07))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(soft ? 0.10 : 0.15), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(LinearGradient(colors: [.white.opacity(soft ? 0.16 : 0.3), .clear, .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1))
        .shadow(color: .black.opacity(soft ? 0 : 0.25), radius: 18, y: 10)
    }
}
extension View { func vioraGlass(_ radius: CGFloat = 20, soft: Bool = false) -> some View { modifier(GlassSurface(radius: radius, soft: soft)) } }
struct FieldLabel: View {
    var text: String
    var body: some View { Text(text.uppercased()).font(VioraTheme.text(11, .semibold)).tracking(1.3).foregroundStyle(.white.opacity(0.62)) }
}
struct IconButton: View {
    var icon: String
    var label: String
    var action: () -> Void
    var body: some View { Button(action: action) { Image(systemName: icon).font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44).vioraGlass(14) }.buttonStyle(.plain).accessibilityLabel(label) }
}
struct Chip: View {
    var label: String
    var selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(VioraTheme.text(13,.semibold)).foregroundStyle(.white.opacity(selected ? 1 : 0.8)).padding(.horizontal,16).frame(minHeight:44)
                .background(selected ? VioraTheme.violet.opacity(0.30) : .white.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
                .overlay(RoundedRectangle(cornerRadius:14).strokeBorder(selected ? Color(red:176/255,green:164/255,blue:1).opacity(0.65) : .white.opacity(0.12)))
                .shadow(color:selected ? VioraTheme.violet.opacity(0.2) : .clear,radius:4)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
#if os(iOS)
@MainActor func dismissKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
struct KeyboardDismiss: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button { dismissKeyboard() } label: { HStack(spacing: 6) { Text("Tastatur ausblenden"); Image(systemName: "keyboard.chevron.compact.down") } }.accessibilityIdentifier("hideKeyboard")
            }
        }
    }
}
#else
@MainActor func dismissKeyboard() { NSApp.keyWindow?.makeFirstResponder(nil) }
struct KeyboardDismiss: ViewModifier { func body(content: Content) -> some View { content } }
#endif

struct StudioRoot: View {
    @Bindable var studio: StudioModel
    @State private var options = false
    @State private var detail: GalleryEntry?
    @State private var keyboardVisible = false
    @State private var gallerySearch = false
    @Namespace private var navigationAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                Group {
                    #if os(macOS)
                    desktop
                    #else
                    VStack(spacing:0) {
                        ScrollView {
                            VStack(alignment: .leading,spacing:14) {
                                header.vioraEntrance()
                                page.id(studio.tab)
                            }.padding(.horizontal,18).padding(.top,max(58 - geometry.safeAreaInsets.top,8)).padding(.bottom,18)
                        }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively).frame(maxHeight:.infinity).clipped()
                        if !keyboardVisible {
                            VStack(spacing:12) {
                                if studio.tab == "Erstellen" { GenerateButton(studio:studio).padding(.horizontal,18) }
                                navigation.padding(.horizontal,16)
                            }.padding(.top,12).padding(.bottom,8)
                        }
                    }
                    #endif
                }.frame(maxWidth:.infinity,maxHeight:.infinity).background(StudioBackdrop())
                    .font(VioraTheme.text()).foregroundStyle(Color(red:243/255,green:244/255,blue:247/255))
            }
            #if os(iOS)
            .toolbar(.hidden,for:.navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
            #endif
            .modifier(KeyboardDismiss())
        }
        .sheet(isPresented:$studio.showSettings) { SettingsPanel(studio:studio) }
        .sheet(isPresented:$options) { OptionsPanel(studio:studio, section: .all) }
        .sheet(item:$detail) { EntryDetail(studio:studio,entry:$0) }
        .alert("Viora Studio",isPresented:Binding(get:{studio.error != nil},set:{if !$0 {studio.error=nil}})) { Button("OK"){studio.error=nil} } message:{Text(studio.error ?? "")}
        .alert("Gespeichert",isPresented:Binding(get:{studio.notice != nil},set:{if !$0 {studio.notice=nil}})) { Button("OK"){studio.notice=nil} } message:{Text(studio.notice ?? "")}
    }
    var header: some View {
        HStack {
            VStack(alignment:.leading,spacing:2) { Text("Viora Studio").font(VioraTheme.text(13,.semibold)).foregroundStyle(.white.opacity(0.62)); Text(studio.tab).font(VioraTheme.title()).tracking(-0.5) }
            Spacer()
            if studio.tab == "Erstellen" {
                Button { dismissKeyboard(); studio.showSettings=true } label: {
                    HStack(spacing:7) {
                        if studio.connecting { ProgressView().controlSize(.mini) }
                        else { Circle().fill(studio.connected ? Color(red:74/255,green:222/255,blue:128/255) : studio.connectionError != nil ? .orange : .gray).frame(width:7,height:7) }
                        Text(studio.connecting ? "Verbinde …" : studio.connected ? "Online" : studio.connectionError != nil ? "Prüfen" : "Verbinden").font(VioraTheme.text(12,.semibold))
                    }.padding(.horizontal,12).padding(.vertical,8).vioraGlass(99)
                }.buttonStyle(.plain).frame(minHeight:44).accessibilityIdentifier("connection")
            } else if studio.tab == "Galerie" {
                IconButton(icon:"magnifyingglass",label:"Galerie durchsuchen") {gallerySearch.toggle()}
            } else if studio.tab == "Queue" {
                IconButton(icon:studio.paused ? "play.fill" : "pause.fill",label:studio.paused ? "Queue fortsetzen" : "Queue pausieren") { if studio.paused {studio.resumeQueue()} else {studio.paused=true} }
            } else { IconButton(icon:"slider.horizontal.3",label:"Einstellungen") {studio.showSettings=true} }
        }
    }
    @ViewBuilder var page: some View {
        if studio.tab == "Erstellen" { CreatePanel(studio:studio,detail:$detail) }
        else if studio.tab == "Galerie" { GalleryPanel(studio:studio,detail:$detail,searchVisible:gallerySearch) }
        else if studio.tab == "Queue" { QueuePanel(studio:studio) }
        else { ModelsPanel(studio:studio) }
    }
    var navigation: some View {
        HStack(spacing:0) {
            ForEach(Array(zip(["Erstellen","Galerie","Queue","Modelle"],["sparkle","square.grid.2x2","list.bullet","cube"])),id:\.0) { tab,icon in
                Button { dismissKeyboard(); withAnimation(reduceMotion ? nil : .spring(response:0.45,dampingFraction:0.8)) {studio.tab=tab} } label: {
                    VStack(spacing:4) {Image(systemName:icon).font(.system(size:20,weight:.regular)); Text(tab).font(VioraTheme.text(10,.semibold))}
                        .foregroundStyle(.white.opacity(studio.tab == tab ? 1 : 0.62)).frame(maxWidth:.infinity,minHeight:54)
                        .background {
                            if studio.tab == tab { RoundedRectangle(cornerRadius:18).fill(.white.opacity(0.12)).overlay(RoundedRectangle(cornerRadius:18).strokeBorder(.white.opacity(0.16))).matchedGeometryEffect(id:"activeTab",in:navigationAnimation) }
                        }
                }.buttonStyle(.plain).accessibilityAddTraits(studio.tab == tab ? [.isSelected] : []).accessibilityIdentifier("tab-\(tab)")
            }
        }.padding(6).vioraGlass(28)
    }
    #if os(macOS)
    var desktop: some View {
        VStack(spacing:20) {
            HStack(alignment:.center,spacing:30) {header; navigation.frame(maxWidth:400)}.padding(.horizontal,28).padding(.top,20)
            if studio.tab == "Erstellen" {
                HSplitView {
                    ScrollView { CreatePanel(studio:studio,detail:$detail).padding(24) }.frame(minWidth:350,idealWidth:410,maxWidth:480)
                    ScrollView { VStack(spacing:20) {
                        PreviewCanvas(studio:studio,height:420,detail:$detail)
                        QueuePanel(studio:studio)
                    }.padding(24) }.frame(minWidth:400)
                }
            } else { ScrollView {page.padding(28)} }
        }
    }
    #endif
}

struct CreatePanel: View {
    @Bindable var studio: StudioModel
    @Binding var detail: GalleryEntry?
    @State private var sheet: OptionSection?
    @State private var inlineVideo: OptionSection? = .quantity
    @FocusState private var promptFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var modeAnimation
    private var formats: [(String,Int,Int)] {
        studio.draft.video ? [("9:16",288,512),("1:1",512,512),("4:5",384,480),("16:9",512,288),("16:10",512,320)] : [("9:16",768,1344),("1:1",1024,1024),("4:5",896,1120),("16:9",1344,768),("21:9",1536,640)]
    }
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(spacing:0) {
                ForEach([false,true],id:\.self) { video in
                    Button { promptFocused=false; dismissKeyboard(); withAnimation(reduceMotion ? nil : .spring(response:0.45,dampingFraction:0.75)) {studio.selectMode(video)} } label: {
                        Text(video ? "Video" : "Bild").font(VioraTheme.text(14,.bold)).frame(maxWidth:.infinity,minHeight:44)
                            .background {
                                if studio.draft.video == video { RoundedRectangle(cornerRadius:12).fill(.white.opacity(0.17)).overlay(RoundedRectangle(cornerRadius:12).strokeBorder(.white.opacity(0.28))).matchedGeometryEffect(id:"mode",in:modeAnimation) }
                            }
                    }.buttonStyle(.plain).accessibilityAddTraits(studio.draft.video == video ? [.isSelected] : [])
                }
            }.padding(4).vioraGlass(16,soft:true).vioraEntrance(0.08)
            #if os(iOS)
            PreviewCanvas(studio:studio,height:230,detail:$detail).vioraEntrance(0.16)
            #endif
            if studio.draft.video {
                VideoSourceControls(studio:studio).vioraEntrance(0.2)
            }
            VStack(alignment:.leading,spacing:8) {
                FieldLabel(text:"Prompt").frame(maxWidth:.infinity,alignment:.leading).frame(height:16)
                    .overlay(alignment:.trailing) {
                        if promptFocused { Button {promptFocused=false;dismissKeyboard()} label:{Image(systemName:"keyboard.chevron.compact.down").frame(width:44,height:44)}.buttonStyle(.plain).accessibilityLabel("Tastatur ausblenden").accessibilityIdentifier("hideKeyboardInline") }
                    }
                TextField("Was soll entstehen?",text:$studio.draft.prompt,axis:.vertical)
                    .font(VioraTheme.text(15)).lineSpacing(3).lineLimit(3...6).focused($promptFocused).autocorrectionDisabled()
                    .padding(14).frame(minHeight:96,alignment:.topLeading).background(.black.opacity(0.25),in:RoundedRectangle(cornerRadius:18))
                    .overlay(RoundedRectangle(cornerRadius:18).strokeBorder(promptFocused ? VioraTheme.violet.opacity(0.7) : .white.opacity(0.12)))
                    .accessibilityIdentifier("prompt")
            }.vioraEntrance(0.24)
            VStack(alignment:.leading,spacing:8) {
                FieldLabel(text:"Format")
                ScrollView(.horizontal) { HStack(spacing:8) {
                    ForEach(formats,id:\.0) { label,width,height in
                        Chip(label:label,selected:studio.draft.width == width && studio.draft.height == height) { withAnimation(reduceMotion ? nil : .easeInOut(duration:0.25)) { studio.draft.width=width;studio.draft.height=height };promptFocused=false;dismissKeyboard() }
                    }
                }.padding(.vertical,3) }.scrollIndicators(.hidden)
            }.vioraEntrance(0.24)
            StyleSelection(studio:studio).vioraEntrance(0.24)
            HStack(spacing:8) {
                compactButton("Modell",value:shortModel,section:.models)
                compactButton(studio.draft.video ? "Länge" : "Anzahl",value:studio.draft.video ? String(format:"%.1f s",Double(studio.draft.frames)/Double(studio.draft.fps)) : "\(studio.draft.count)×",section:.quantity,mono:true)
                compactButton("Mehr",value:"Optionen",section:.all)
            }.vioraEntrance(0.24)
            if studio.draft.video, let inlineVideo {
                InlineVideoOptions(studio:studio,section:inlineVideo) {
                    dismissKeyboard(); withAnimation(reduceMotion ? nil : .easeInOut(duration:0.25)) { self.inlineVideo=nil }
                }.transition(.opacity.combined(with:.move(edge:.top)))
            }
            #if os(macOS)
            GenerateButton(studio:studio).vioraEntrance(0.32)
            #endif
        }.sheet(item:$sheet) {OptionsPanel(studio:studio,section:$0)}
            .onChange(of:studio.draft.video) { _,video in if video {sheet=nil;inlineVideo = .quantity} }
    }
    var shortModel: String {
        let model=studio.draft.video ? studio.draft.videoModel : studio.draft.model
        if model.isEmpty {return "Auswählen"}
        if model.lowercased().contains("sd_xl") {return "SDXL Base"}
        if model.lowercased().contains("wan2.2") {return "Wan 2.2"}
        return URL(fileURLWithPath:model).deletingPathExtension().lastPathComponent
    }
    func compactButton(_ title:String,value:String,section:OptionSection,mono:Bool=false)->some View {
        Button {
            promptFocused=false;dismissKeyboard()
            if studio.draft.video {withAnimation(reduceMotion ? nil : .spring(response:0.4,dampingFraction:0.9)) {inlineVideo = inlineVideo == section ? nil : section}}
            else {sheet=section}
        } label: {
            VStack(alignment:.leading,spacing:6) {Text(title.uppercased()).font(VioraTheme.text(10,.semibold)).tracking(1).foregroundStyle(.white.opacity(0.62)); Text(value).font(mono ? VioraTheme.mono(13) : VioraTheme.text(13,.bold)).lineLimit(1)}
                .padding(10).frame(maxWidth:.infinity,minHeight:56,alignment:.leading).vioraGlass(16,soft:true)
                .overlay(RoundedRectangle(cornerRadius:16).strokeBorder(studio.draft.video && inlineVideo == section ? VioraTheme.violet.opacity(0.8) : .clear))
        }.buttonStyle(.plain)
    }
}
struct GenerateButton: View {
    @Bindable var studio: StudioModel
    var body: some View {
        Button {dismissKeyboard();studio.enqueue()} label: {
            Label(studio.busy ? "Zur Queue hinzufügen" : studio.draft.video ? "Video generieren" : "Generieren",systemImage:"sparkle").font(VioraTheme.title(16))
                .frame(maxWidth:.infinity,minHeight:58).background(VioraTheme.gradient,in:RoundedRectangle(cornerRadius:20))
                .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(.white.opacity(0.35)))
                .overlay(MovingSheen().clipShape(RoundedRectangle(cornerRadius:20)))
                .shadow(color:VioraTheme.violet.opacity(0.4),radius:14,y:8)
        }.buttonStyle(GeneratePressStyle()).disabled(!studio.canGenerate).opacity(studio.canGenerate ? 1 : 0.55).accessibilityIdentifier("generate")
    }
}
struct GeneratePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration)->some View {configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1).animation(reduceMotion ? nil : .easeOut(duration:0.2),value:configuration.isPressed)}
}
struct MovingSheen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var period: Double = 3
    var restFraction: Double = 0.6
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval:1/30,paused:reduceMotion)) { context in
                let cycle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy:period) / period
                let progress = max(0,(cycle - restFraction) / (1 - restFraction))
                if !reduceMotion {
                    LinearGradient(colors:[.clear,.white.opacity(0.35),.clear],startPoint:.leading,endPoint:.trailing)
                        .frame(width:geometry.size.width * 0.7).rotationEffect(.degrees(12))
                        .offset(x:geometry.size.width * (-0.85 + progress * 2.2))
                }
            }
        }.clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}
struct PreviewGradient: View {
    var body: some View {
        GeometryReader {g in
            ZStack {
                LinearGradient(colors:[Color(red:26/255,green:27/255,blue:58/255),Color(red:74/255,green:44/255,blue:58/255)],startPoint:.top,endPoint:.bottom)
                Ellipse().fill(Color(red:124/255,green:156/255,blue:1).opacity(0.85)).frame(width:g.size.width*0.8,height:g.size.height*0.8).blur(radius:40).offset(x:-g.size.width*0.2,y:-g.size.height*0.2)
                Ellipse().fill(Color(red:1,green:107/255,blue:138/255).opacity(0.55)).frame(width:g.size.width*0.5,height:g.size.height*0.6).blur(radius:40).offset(x:g.size.width*0.3,y:-g.size.height*0.1)
                Ellipse().fill(Color(red:1,green:170/255,blue:120/255).opacity(0.85)).frame(width:g.size.width*0.45,height:g.size.height*0.5).blur(radius:30).offset(y:g.size.height*0.45)
            }
        }
    }
}
struct PreviewCanvas: View {
    @Bindable var studio: StudioModel
    var height: CGFloat
    @Binding var detail: GalleryEntry?
    @State private var importing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            PreviewGradient()
            if let data=studio.previewData,let image=PlatformImage(data:data) {image.resizable().scaledToFit()}
            else if studio.draft.video, let data=studio.inputImageData,let image=PlatformImage(data:data) {image.resizable().scaledToFit()}
            else if !studio.draft.video, let entry=studio.selected,let url=studio.mediaURL(entry) {MediaView(url:url,video:entry.mediaType == "video")}
            else if studio.draft.video && studio.draft.initImage == nil {
                Button {importing=true} label:{Label("Ausgangsbild wählen",systemImage:"photo.badge.plus").font(VioraTheme.text(13,.semibold)).padding(14).vioraGlass(18)}.buttonStyle(.plain)
            }
            if let job=studio.activeJob {
                MovingSheen(period:1.5,restFraction:0)
                VStack(spacing:10) {
                    if let progress=job.progress {Text(progress,format:.percent.precision(.fractionLength(0))).font(VioraTheme.mono(26)); ProgressView(value:progress).tint(VioraTheme.cyan).frame(width:160)}
                    else {ProgressView();Text(studio.activeStatusText).font(VioraTheme.text(12))}
                }.padding(.horizontal,20).padding(.vertical,14).frame(minWidth:200).vioraGlass(22)
            }
        }.frame(height:height).clipShape(RoundedRectangle(cornerRadius:26))
            .overlay(alignment:.bottomLeading) {Text(studio.draft.video ? "Ausgangsbild · \(studio.draft.width) × \(studio.draft.height)" : studio.selected != nil ? "\(studio.selected!.request.width) × \(studio.selected!.request.height)" : "Vorschau · \(studio.draft.width) × \(studio.draft.height)").font(VioraTheme.mono(11)).padding(.horizontal,10).padding(.vertical,6).vioraGlass(12).padding(10)}
            .overlay(alignment:.topTrailing) {
                if studio.draft.video { IconButton(icon:"photo.badge.plus",label:"Ausgangsbild ändern") {importing=true}.padding(10) }
                else {IconButton(icon:"arrow.up.right.and.arrow.down.left",label:"Vollbild") {detail=studio.selected}.disabled(studio.selected == nil).padding(10)}
            }
            .overlay(RoundedRectangle(cornerRadius:26).strokeBorder(.white.opacity(0.14)))
            .phaseAnimator(reduceMotion ? [false] : [false,true]) { content, phase in content.scaleEffect(phase ? 1.025 : 1) } animation: { _ in .easeInOut(duration:2) }
            .fileImporter(isPresented:$importing,allowedContentTypes:[.image]) {result in do {studio.importImage(try result.get())} catch {studio.report(error)}}
    }
}

struct GalleryPanel: View {
    @Bindable var studio: StudioModel
    @Binding var detail: GalleryEntry?
    var searchVisible = false
    @State private var filter = "Alle"
    @State private var query = ""
    private var entries:[GalleryEntry] {studio.gallery.filter {entry in (filter != "Favoriten" || entry.favorite) && (filter != "Bilder" || entry.mediaType == "image") && (filter != "Videos" || entry.mediaType == "video") && (query.isEmpty || entry.request.prompt.localizedCaseInsensitiveContains(query))}}
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            if searchVisible {TextField("Galerie durchsuchen",text:$query).padding(14).vioraGlass(18,soft:true).autocorrectionDisabled()}
            ScrollView(.horizontal) {HStack(spacing:8) {ForEach(["Alle","Bilder","Videos","Favoriten"],id:\.self) {item in Chip(label:item,selected:filter == item) {withAnimation(.easeInOut(duration:0.2)){filter=item}}}}}.scrollIndicators(.hidden).padding(.vertical,3)
            if entries.isEmpty {Text("Hier erscheinen deine lokal gespeicherten Ergebnisse.").font(VioraTheme.text(14)).foregroundStyle(.white.opacity(0.7)).padding(22).frame(maxWidth:.infinity,alignment:.leading).vioraGlass(22,soft:true)}
            HStack(alignment:.top,spacing:10) {
                ForEach(0..<2,id:\.self) {column in
                    LazyVStack(spacing:10) {ForEach(Array(entries.enumerated()).filter {$0.offset % 2 == column},id:\.element.id) { index,entry in GalleryTile(studio:studio,entry:entry){detail=entry;studio.selected=entry}.vioraEntrance(Double(index % 6) * 0.05,pop:true)}}.frame(maxWidth:.infinity)
                }
            }
        }.vioraEntrance(0.08)
    }
}
struct GalleryTile: View {
    @Bindable var studio: StudioModel
    let entry: GalleryEntry
    let open: () -> Void
    var body: some View {
        Button(action:open) {
            ZStack {
                Color.black.opacity(0.2)
                if let url=studio.mediaURL(entry) {MediaThumbnail(url:url,video:entry.mediaType == "video")}
            }.frame(height:entry.mediaType == "video" ? 150 : min(260,max(150,170 * CGFloat(entry.request.height)/CGFloat(entry.request.width))))
                .clipShape(RoundedRectangle(cornerRadius:22))
                .overlay(RoundedRectangle(cornerRadius:22).strokeBorder(.white.opacity(0.14)))
                .overlay(alignment:.bottomLeading) {if entry.mediaType == "video" {Label("Video",systemImage:"play.fill").font(VioraTheme.mono(11)).padding(.horizontal,8).padding(.vertical,5).vioraGlass(10).padding(8)}}
        }.buttonStyle(GeneratePressStyle()).accessibilityLabel(entry.request.prompt)
            .overlay(alignment:.topTrailing) {
                Button {studio.toggleFavorite(entry)} label:{Image(systemName:entry.favorite ? "heart.fill" : "heart").font(.system(size:14)).foregroundStyle(entry.favorite ? VioraTheme.pink : .white.opacity(0.75)).frame(width:32,height:32).vioraGlass(10).frame(width:44,height:44)}.buttonStyle(.plain).accessibilityLabel("Favorit umschalten").padding(2)
            }
    }
}
struct QueuePanel: View {
    @Bindable var studio: StudioModel
    private var waiting:[QueueJob] {studio.jobs.filter {$0.state == .waiting}}
    private var history:[QueueJob] {studio.jobs.filter {!$0.active && $0.state != .waiting}.reversed()}
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            if let active=studio.activeJob {
                ZStack(alignment:.bottom) {
                    PreviewGradient()
                    MovingSheen(period:1.5,restFraction:0)
                    if let data=studio.previewData,let image=PlatformImage(data:data) {image.resizable().scaledToFill()}
                    VStack(alignment:.leading,spacing:8) {
                        HStack {Text(active.request.prompt).font(VioraTheme.text(14,.bold)).lineLimit(1);Spacer();ProgressView().controlSize(.small)}
                        if let progress=active.progress {ProgressView(value:progress).tint(VioraTheme.cyan)}
                        HStack {
                            Text(active.progress.map{String(format:"Läuft · %.0f %%",$0*100)} ?? studio.activeStatusText).font(VioraTheme.mono(11)).foregroundStyle(.white.opacity(0.72));Spacer()
                            Button("Abbrechen",role:.destructive){Task{await studio.cancel(active.id)}}.font(VioraTheme.text(11,.semibold)).frame(minHeight:44).disabled(active.state == .cancelling)
                            Button {Task{await studio.removeJob(active.id)}} label:{Image(systemName:"trash").frame(width:44,height:44)}.buttonStyle(.plain).foregroundStyle(VioraTheme.pink).accessibilityLabel("Laufenden Auftrag stoppen und löschen").disabled(active.state == .cancelling)
                        }
                    }.padding(.horizontal,14).padding(.vertical,8).vioraGlass(18).padding(10)
                }.frame(height:200).clipShape(RoundedRectangle(cornerRadius:26)).overlay(RoundedRectangle(cornerRadius:26).strokeBorder(.white.opacity(0.14)))
            }
            if studio.paused {Text("Queue pausiert").font(VioraTheme.text(13,.semibold)).foregroundStyle(VioraTheme.violet);Button("Wartende Aufträge fortsetzen"){studio.resumeQueue()}.frame(minHeight:44).disabled(!studio.connected || studio.busy)}
            FieldLabel(text:"Als Nächstes").padding(.top,4)
            if waiting.isEmpty {Text("Keine wartenden Aufträge").font(VioraTheme.text(13)).foregroundStyle(.white.opacity(0.62)).padding(18).frame(maxWidth:.infinity,alignment:.leading).vioraGlass(20,soft:true)}
            ForEach(waiting) {job in jobRow(job)}
            HStack {
                VStack(alignment:.leading,spacing:6) {FieldLabel(text:"Backend");Label(studio.connected ? "Online" : "Nicht verbunden",systemImage:"circle.fill").font(VioraTheme.text(13,.bold)).foregroundStyle(studio.connected ? .green : .secondary)}.frame(maxWidth:.infinity,alignment:.leading)
                VStack(alignment:.leading,spacing:6) {FieldLabel(text:"Serverstatus");Text(studio.serverStatus.map{"\($0.live_gens ?? 0) aktiv"} ?? "–").font(VioraTheme.mono(13))}.frame(maxWidth:.infinity,alignment:.leading)
            }.padding(14).vioraGlass(20,soft:true)
            if !history.isEmpty {FieldLabel(text:"Verlauf").padding(.top,4);ForEach(history) {job in jobRow(job)}}
            if !studio.jobs.isEmpty {Text("Löschen entfernt den Auftrag aus der Queue. Gespeicherte Ergebnisse bleiben in deiner Galerie.").font(VioraTheme.text(11)).foregroundStyle(.secondary)}
        }.vioraEntrance(0.08)
    }
    func jobRow(_ job:QueueJob)->some View {
        HStack(spacing:12) {
            Image(systemName:job.request.video ? "video" : "photo").font(.system(size:21,weight:.light)).foregroundStyle(VioraTheme.violet).frame(width:56,height:56).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
            VStack(alignment:.leading,spacing:4) {
                Text(job.request.prompt).font(VioraTheme.text(14,.bold)).lineLimit(2)
                Text(job.state == .waiting ? "\(job.request.video ? "Video" : "Bild") · \(job.request.count)× · \(job.request.width)×\(job.request.height)" : job.state.rawValue).font(VioraTheme.mono(11)).foregroundStyle(.white.opacity(0.62))
                if job.state == .failed || job.state == .uncertain {Text(job.detail).font(VioraTheme.text(11)).foregroundStyle(.orange)}
            }.frame(maxWidth:.infinity,alignment:.leading)
            if job.state == .done {Image(systemName:"checkmark.circle").foregroundStyle(VioraTheme.cyan)}
            Button {Task{await studio.removeJob(job.id)}} label:{Image(systemName:"trash").frame(width:44,height:44)}.buttonStyle(.plain).foregroundStyle(.white.opacity(0.7)).accessibilityLabel("Auftrag aus Queue löschen").accessibilityIdentifier("deleteJob-\(job.id)")
        }.padding(10).vioraGlass(20,soft:true)
    }
}
struct ModelsPanel: View {
    @Bindable var studio: StudioModel
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            if studio.models.isEmpty {Text("Verbinde deinen Server, um die verfügbaren Modelle zu sehen.").font(VioraTheme.text(14)).padding(18).vioraGlass(20,soft:true)}
            ForEach(studio.models) {model in
                HStack(spacing:14) {Image(systemName:model.isVideo ? "video" : "cube").font(.title2).foregroundStyle(VioraTheme.violet);VStack(alignment:.leading,spacing:6){Text(model.name).font(VioraTheme.text(14,.bold));Text(model.architecture ?? "").font(VioraTheme.mono(10)).foregroundStyle(.white.opacity(0.62))}}.padding(18).frame(maxWidth:.infinity,alignment:.leading).vioraGlass(20,soft:true)
            }
            Button("Modelle aktualisieren"){Task{await studio.connect()}}.frame(minHeight:44).disabled(studio.connecting || studio.busy)
        }
    }
}
enum OptionSection:String,Identifiable {case models="Modell",quantity="Anzahl & Länge",all="Optionen";var id:String{rawValue}}
struct OptionsPanel: View {
    @Bindable var studio: StudioModel
    var section: OptionSection
    @Environment(\.dismiss) private var dismiss
    @State private var importing=false
    var body: some View {
        NavigationStack {
            Form {
                if section == .models || section == .all {
                    Section("Modelle") {
                        modelPicker("Basismodell",selection:$studio.draft.model,models:studio.models.filter{!$0.isVideo})
                        if studio.draft.video {modelPicker("HighNoise",selection:$studio.draft.videoModel,models:studio.models.filter(\.isVideo));modelPicker("LowNoise",selection:$studio.draft.swapModel,models:studio.models.filter(\.isVideo))}
                        Button("Server & Einstellungen"){dismiss();studio.showSettings=true}.frame(minHeight:44)
                    }
                }
                if section == .quantity || section == .all {
                    Section("Ausgabe") {
                        Stepper("Anzahl: \(studio.draft.count)",value:$studio.draft.count,in:1...4).frame(minHeight:44)
                        Stepper("Qualität: \(studio.draft.steps) Schritte",value:$studio.draft.steps,in:1...80).frame(minHeight:44)
                        if studio.draft.video {Stepper("\(studio.draft.frames) Frames",value:$studio.draft.frames,in:9...81,step:4).frame(minHeight:44);Text("\(Double(studio.draft.frames)/Double(studio.draft.fps),specifier:"%.1f") Sekunden bei \(studio.draft.fps) FPS").font(VioraTheme.mono(12));Text("Wan A14B benötigt mehrere Minuten. 49 Frames sind der Standard.").font(.caption)}
                    }
                }
                if section == .all {
                    Section("Stil") {
                        Picker("Stil",selection:$studio.draft.style){ForEach(VisualStyle.allCases,id:\.self){Text($0.rawValue).tag($0)}}.onChange(of:studio.draft.style){_,style in studio.draft.styleSuffix=style.suffix}
                        TextField("Stilzusatz",text:$studio.draft.styleSuffix,axis:.vertical).lineLimit(2...4).autocorrectionDisabled()
                        Text("Stile ergänzen deinen Prompt. Der Zusatz ist frei editierbar.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Ausgangsbild") {
                        if let raw=studio.draft.initImage,let comma=raw.firstIndex(of:","),let data=Data(base64Encoded:String(raw[raw.index(after:comma)...])),let image=PlatformImage(data:data){image.resizable().scaledToFit().frame(height:110)}
                        Button("Bild auswählen"){importing=true}.frame(minHeight:44)
                        if studio.draft.initImage != nil {Button("Bild entfernen",role:.destructive){studio.draft.initImage=nil}.frame(minHeight:44)}
                        if !studio.draft.video && studio.draft.initImage != nil {Slider(value:$studio.draft.creativity,in:0...1){Text("Kreativität")}}
                    }
                    Section("Weitere Parameter") {
                        TextField("Negativ-Prompt",text:$studio.draft.negative,axis:.vertical).lineLimit(2...5).autocorrectionDisabled()
                        HStack{Text("Seed");TextField("−1 = zufällig",value:$studio.draft.seed,format:.number.grouping(.never)).font(VioraTheme.mono())}
                        Text("−1 wählt einen zufälligen Seed.").font(.caption).foregroundStyle(.secondary)
                        HStack{Text("CFG");Slider(value:$studio.draft.cfg,in:1...20,step:0.5);Text(studio.draft.cfg,format:.number.precision(.fractionLength(1))).monospacedDigit()}
                        parameterPicker("Sampler",key:"sampler",selection:$studio.draft.sampler)
                        parameterPicker("Scheduler",key:"scheduler",selection:$studio.draft.scheduler)
                    }
                }
            }.formStyle(.grouped).scrollContentBackground(.hidden).background(StudioBackdrop()).navigationTitle(section.rawValue)
                .toolbar{Button("Fertig"){dismissKeyboard();dismiss()}}.modifier(KeyboardDismiss())
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
        }.font(VioraTheme.text()).preferredColorScheme(.dark).frame(minWidth:320,idealWidth:520,minHeight:430)
            .fileImporter(isPresented:$importing,allowedContentTypes:[.image]){result in do{studio.importImage(try result.get())}catch{studio.report(error)}}
    }
    func modelPicker(_ label:String,selection:Binding<String>,models:[SwarmModel])->some View {Picker(label,selection:selection){Text("Auswählen").tag("");ForEach(models){Text($0.name).tag($0.name)}}}
    func parameterPicker(_ title:String,key:String,selection:Binding<String>)->some View {Picker(title,selection:selection){ForEach(studio.specs.first{$0.id == key}?.values ?? [selection.wrappedValue],id:\.self){Text($0).tag($0)}}}
}
struct EntryDetail: View {
    @Bindable var studio:StudioModel
    let entry:GalleryEntry
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:18){
                    if let url=studio.mediaURL(entry){MediaView(url:url,video:entry.mediaType == "video").frame(minHeight:300).clipShape(RoundedRectangle(cornerRadius:22))}
                    Text(entry.request.prompt).textSelection(.enabled)
                    Text("\(entry.request.style.rawValue) · \(entry.request.model)").font(VioraTheme.text(12)).foregroundStyle(.secondary)
                    Text("Seed: \(entry.seed.map(String.init) ?? "Vom Server nicht gemeldet")").font(VioraTheme.mono(11))
                    if let url=studio.mediaURL(entry){ShareLink(item:url){Label("Teilen / In Dateien sichern",systemImage:"square.and.arrow.up").frame(minHeight:44)}}
                    Button{studio.toggleFavorite(entry)}label:{Label("Favorit umschalten",systemImage:"heart").frame(minHeight:44)}
                    if entry.mediaType == "image"{Button{studio.animate(entry);dismiss()}label:{Label("Bild animieren",systemImage:"video.badge.plus").frame(minHeight:44)}}
                    #if os(iOS)
                    Button{Task{await studio.saveToPhotos(entry)}}label:{Label("In Fotos speichern",systemImage:"photo.on.rectangle").frame(minHeight:44)}
                    #endif
                }.padding(18)
            }.background(StudioBackdrop()).navigationTitle("Dein Ergebnis").toolbar{Button("Fertig"){dismiss()}}
        }.font(VioraTheme.text()).preferredColorScheme(.dark).frame(minWidth:320,minHeight:480)
    }
}
struct MediaThumbnail:View {
    let url:URL
    let video:Bool
    @State private var image:CGImage?
    var body:some View {
        Group {if let image{Image(decorative:image,scale:1).resizable().scaledToFill()}else{Image(systemName:video ? "play.rectangle" : "photo").foregroundStyle(.white.opacity(0.6))}}
            .task(id:url){
                if video {let generator=AVAssetImageGenerator(asset:AVURLAsset(url:url));generator.maximumSize=CGSize(width:700,height:700);generator.appliesPreferredTrackTransform=true;image=try? await generator.image(at:.zero).image}
                else if let source=CGImageSourceCreateWithURL(url as CFURL,nil){image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:700,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary)}
            }
    }
}

func PlatformImage(data: Data) -> Image? {
    #if os(macOS)
    return NSImage(data: data).map { Image(nsImage: $0) }
    #else
    return UIImage(data: data).map { Image(uiImage: $0) }
    #endif
}
struct MediaView: View {
    let url: URL
    let video: Bool
    @State private var player: AVPlayer?
    @State private var image: CGImage?
    var body: some View {
        Group {
            if video { VideoPlayer(player: player) }
            else if let image { Image(decorative: image, scale: 1).resizable().scaledToFit() }
            else { Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary) }
        }.task(id: url) {
            if video { player = AVPlayer(url: url) }
            else {
                let source = CGImageSourceCreateWithURL(url as CFURL, nil)
                image = source.flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1400, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) }
            }
        }.onDisappear { player?.pause() }
    }
}

struct SettingsPanel: View {
    @Bindable var studio: StudioModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Privater Server") {
                    TextField("https://dein-server:8443/", text: $studio.serverAddress).textContentType(.URL).autocorrectionDisabled().disabled(studio.busy || studio.connecting).accessibilityIdentifier("serverURL")
                    .onChange(of: studio.serverAddress) { _, _ in studio.serverAddressChanged() }
                    #if os(iOS)
                    .textInputAutocapitalization(.never).keyboardType(.URL)
                    .submitLabel(.go).onSubmit { dismissKeyboard(); Task { await studio.connect() } }
                    #endif
                    Text("Tailscale auf diesem iPhone bzw. Mac und dem Windows-Server einschalten. Die Serveradresse muss den richtigen Port enthalten, zum Beispiel :8443.").font(.caption).foregroundStyle(.secondary)
                    if let preset=studio.configuredServerAddress, !studio.connected {
                        Button("Voreingestellten Server verwenden") { studio.serverAddress=preset; dismissKeyboard(); Task { await studio.connect() } }.disabled(studio.busy || studio.connecting).frame(minHeight:44)
                    }
                    Button { dismissKeyboard(); Task { await studio.connect() } } label: {
                        HStack(spacing:10) {
                            if studio.connecting { ProgressView() }
                            Image(systemName:studio.connected ? "checkmark.circle.fill" : "link")
                            Text(studio.connecting ? "Verbindung wird geprüft …" : studio.connected ? "Verbindung erneut prüfen" : "Verbinden & Modelle laden")
                        }.frame(maxWidth:.infinity,minHeight:48).foregroundStyle(.white)
                            .background(VioraTheme.gradient,in:RoundedRectangle(cornerRadius:16))
                    }.buttonStyle(GeneratePressStyle()).disabled(studio.busy || studio.connecting).accessibilityIdentifier("connect")
                    Label(studio.connectionMessage,systemImage:studio.connected ? "checkmark.circle.fill" : studio.connectionError == nil ? "network" : "exclamationmark.triangle")
                        .font(VioraTheme.text(13,.semibold)).foregroundStyle(studio.connected ? .green : studio.connectionError == nil ? .secondary : .orange).accessibilityIdentifier("connectionStatus")
                    if let error=studio.connectionError { Text(error).font(VioraTheme.text(13)).foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("connectionError") }
                    Text("Nach erfolgreicher Kopplung wird die Verbindung beim App-Start automatisch wiederhergestellt.").font(.caption).foregroundStyle(.secondary)
                    if !studio.version.isEmpty { Text("SwarmUI \(studio.version)").font(.caption.monospaced()) }
                }
                Section("Lokale Galerie") {
                    #if os(macOS)
                    Text(studio.galleryDirectory?.path ?? "Kein Ordner verfügbar").font(.caption).textSelection(.enabled)
                    Button("Galerieordner wählen oder anlegen …") {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
                        panel.begin { response in if response == .OK, let url = panel.url { studio.chooseGallery(url) } }
                    }.disabled(studio.busy)
                    Text("Ein anderer Ordner zeigt dessen Galerie. Vorhandene Dateien werden nicht verschoben.").font(.caption).foregroundStyle(.secondary)
                    #else
                    Text("Bilder und Videos bleiben in der App. Über Teilen kannst du sie in Dateien exportieren; Fotos-Zugriff wird erst beim Speichern angefragt.").font(.caption).foregroundStyle(.secondary)
                    #endif
                }
                Section("Viora Studio 0.1.0 · Build 3") {
                    Link("Releases auf GitHub", destination: URL(string: "https://github.com/Jogurella/Viora-Studio/releases")!)
                    Text("Native Apple-App · iOS 17+ · macOS 14+").font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).scrollContentBackground(.hidden).background(StudioBackdrop()).modifier(KeyboardDismiss()).navigationTitle("Server & Einstellungen").toolbar { Button("Fertig") { dismissKeyboard(); dismiss() } }
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
        }.frame(minWidth: 320, idealWidth: 540, minHeight: 480, idealHeight: 620).preferredColorScheme(.dark)
    }
}
