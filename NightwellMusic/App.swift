import SwiftUI
import UniformTypeIdentifiers

@main struct NightwellMusicApp: App {
    @UIApplicationDelegateAdaptor(DownloadAppDelegate.self) private var appDelegate
    @StateObject private var store = MusicStore()
    var body: some Scene { WindowGroup { NativeRoot().environmentObject(store).preferredColorScheme(.dark) } }
}
enum ServerAddress {
    static func sameOrigin(_ a: URL, _ b: URL) -> Bool { a.scheme == "https" && b.scheme == "https" && a.host == b.host && (a.port ?? 443) == (b.port ?? 443) && b.user == nil && b.password == nil }
    static func validated(_ value: String) -> URL? {
        guard var parts = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)), parts.scheme == "https", let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil, parts.path.isEmpty || parts.path == "/" else { return nil }
        parts.path = "/"; return parts.url
    }
}
let pumpkin = Color(red: 1, green: 0.72, blue: 0.43)
let nightwellViolet = Color(red: 0.19, green: 0.10, blue: 0.29)
let nightwellText = Color(red: 0.94, green: 0.88, blue: 0.97)
extension View {
    func glass(_ radius: CGFloat = 24) -> some View {
        self.background {
            RoundedRectangle(cornerRadius: radius)
                .fill(nightwellViolet.opacity(0.56))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(
                LinearGradient(colors: [pumpkin.opacity(0.33), .white.opacity(0.13), nightwellText.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1
            ))
    }
}

struct NightwellPopup<Content: View>: View {
    let title: String
    var maxHeight: CGFloat = 560
    let close: () -> Void
    let content: Content
    init(title: String, maxHeight: CGFloat = 560, close: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.maxHeight = maxHeight
        self.close = close
        self.content = content()
    }
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.025, green: 0.009, blue: 0.05).opacity(0.72).ignoresSafeArea()
                    .onTapGesture(perform: close)
                content
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: min(maxHeight, proxy.size.height * 0.84))
                    .background {
                        RoundedRectangle(cornerRadius: 30)
                            .fill(LinearGradient(colors: [Color(red: 0.18, green: 0.10, blue: 0.24).opacity(0.98), Color(red: 0.09, green: 0.055, blue: 0.15).opacity(0.98)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(LinearGradient(colors: [pumpkin.opacity(0.24), nightwellText.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 20)
                    .shadow(color: nightwellViolet.opacity(0.65), radius: 28, y: 12)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
        .zIndex(100)
    }
}

struct NativeRoot: View {
    @EnvironmentObject var store: MusicStore
    @State private var settings = false
    @State private var fullPlayer = false
    @State private var backgroundOnly = false
    @State private var importFiles = false
    @State private var selectedPlaylist: Playlist?
    @State private var playlistName = ""
    @State private var createPlaylist = false
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var launching = true
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body: some View {
        ZStack {
            SeasonBackground()
            NativeFogLayer(active: !fullPlayer)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            if !backgroundOnly && store.screen == .home {
                RibbonScene(playing: store.clock.playing, flash: store.likeFlash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            if backgroundOnly { BackgroundOnlyScene(clock: store.clock, lyrics: store.lyrics, flash: store.likeFlash) }
            if backgroundOnly {
                VStack { HStack { Button { backgroundOnly = false } label: { Image(systemName: "xmark").padding().glass() }; Spacer() }; Spacer() }.padding()
            } else {
                VStack(spacing: 18) {
                    header
                    content
                    MiniPlayer(clock: store.clock, open: { fullPlayer = true })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 0)
                        .overlay(alignment: .bottom) {
                            if store.screen == .home {
                                HomeLyricLine(model: store.lyrics, clock: store.clock)
                                    .frame(height: 70)
                                    .padding(.horizontal, 24)
                                    .offset(y: -85)
                            }
                        }
                }
            }
        }
        .overlay {
            if store.authPresented {
                NightwellPopup(title: "", close: { store.authPresented = false }) {
                    AuthSheet(close: { store.authPresented = false })
                }
            } else if settings {
                NightwellPopup(title: "", close: { settings = false }) {
                    NativeSettings(close: { settings = false })
                }
            } else if let playlist = selectedPlaylist {
                NightwellPopup(title: "", maxHeight: 610, close: { selectedPlaylist = nil }) {
                    PlaylistScreen(close: { selectedPlaylist = nil }, playlist: playlist)
                        .id(playlist.id)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: settings)
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: store.authPresented)
        .tint(pumpkin)
        .overlay { if launching { NativeLaunch().transition(.opacity) } }
        .task { try? await Task.sleep(nanoseconds: reducedMotion ? 150_000_000 : 1_200_000_000); withAnimation(.easeOut(duration: 0.3)) { launching = false } }
        .task { await store.start()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--native-smoke-focus") { backgroundOnly = true }
            #endif
        }
        .animation(reducedMotion ? nil : .easeInOut(duration: 0.22), value: store.screen)
        .simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { gesture in
            if gesture.startLocation.x < 24 && gesture.translation.width > 90 && abs(gesture.translation.height) < 60 { store.screen = .home }
        })
        .onChange(of: store.screen) { _ in if store.screen != .search { store.leaveSearch() } }
        .fullScreenCover(isPresented: $fullPlayer) { FullPlayer(clock: store.clock) }
        .sheet(isPresented: $showShare) { if let shareURL { ShareSheet(items: [shareURL]) } }
        .fileImporter(isPresented: $importFiles, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result { Task { await store.importFiles(urls) } }
        }
        .alert("Новый плейлист", isPresented: $createPlaylist) { TextField("Название", text: $playlistName); Button("Создать") { Task { await store.createPlaylist(playlistName); playlistName = "" } }; Button("Отмена", role: .cancel) {} }
        .alert("Nightwell Music", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Понятно") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private var header: some View {
        HStack {
            HStack(spacing: 9) { Image("BrandLogo").resizable().scaledToFit().frame(width: 42, height: 42); VStack(alignment: .leading, spacing: 1) { Text("Nightwell").font(.system(size: 27, weight: .bold)); Text("M U S I C").font(.caption).foregroundStyle(.secondary) } }
            Spacer()
            Button { if store.screen == .search { store.screen = .home } else { store.screen = .search } } label: { Image(systemName: store.screen == .search ? "xmark" : "magnifyingglass").frame(width: 44, height: 44).glass(24) }.accessibilityLabel(store.screen == .search ? "Закрыть поиск" : "Поиск")
            Menu {
                ForEach(MusicStore.Screen.allCases, id: \.self) { screen in Button(screen.rawValue) { store.screen = screen } }
                Divider(); Button("Настройки", systemImage: "gearshape") { settings = true }
                Button(store.account == nil ? "Войти" : "Выйти", systemImage: "person") { if store.account == nil { store.authPresented = true } else { Task { await store.logout() } } }
            } label: { Image(systemName: "line.3.horizontal").frame(width: 44, height: 44).glass(24) }.accessibilityLabel("Меню")
        }.padding(.horizontal, 20).padding(.top, 8)
    }
    @ViewBuilder private var content: some View {
        switch store.screen {
        case .home:
            NativeHome(clock: store.clock, backgroundOnly: $backgroundOnly)
        case .search:
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("Поиск").font(.largeTitle.bold()); Spacer() }
                HStack { Image(systemName: "magnifyingglass"); TextField("Трек или исполнитель", text: $store.query).textInputAutocapitalization(.never).autocorrectionDisabled().onChange(of: store.query) { _ in store.search() }; if !store.query.isEmpty { Button { store.query = "" } label: { Image(systemName: "xmark.circle.fill") } } }.padding(14)
                    .background { RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).opacity(0.48) }
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.28), lineWidth: 1))
                if !store.searchMessage.isEmpty { Text(store.searchMessage).font(.caption).foregroundStyle(.secondary) }
                TrackList(tracks: store.results)
            }.padding(.horizontal, 20)
        case .likes:
            VStack(alignment: .leading) { collectionHeading("Избранное", tracks: store.catalog.filter { store.likes.contains($0.id) }, kind: "likes"); TrackList(tracks: store.catalog.filter { store.likes.contains($0.id) }) }.padding(.horizontal, 20)
        case .playlists:
            VStack(alignment: .leading, spacing: 16) {
                HStack { Text("Плейлисты").font(.largeTitle.bold()); Spacer(); Button { createPlaylist = true } label: { Image(systemName: "plus") } }
                ScrollView { LazyVStack(spacing: 12) { ForEach(store.playlists) { p in
                    HStack { Button { selectedPlaylist = p } label: { Text(p.name).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16) }; Menu {
                        Button("Скачать", systemImage: "arrow.down.to.line") { Task { do { await store.download(try await store.playlistTracks(p.id)) } catch { store.error = error.localizedDescription } } }
                        Button("Поделиться", systemImage: "square.and.arrow.up") { Task { shareURL = await store.share(kind: "playlist", playlist: p.id); showShare = shareURL != nil } }
                        Button("Удалить", role: .destructive) { Task { await store.deletePlaylist(p.id) } }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    }.padding(.horizontal, 18).glass()
                } } }
            }.padding(.horizontal, 20)
        case .offline:
            VStack(alignment: .leading, spacing: 16) { HStack { Text("Офлайн").font(.largeTitle.bold()); Spacer(); Button { importFiles = true } label: { Label("Файлы", systemImage: "folder") } }; Text("Музыка на этом устройстве — без входа").font(.caption).foregroundStyle(.secondary); TrackList(tracks: store.offline) }.padding(.horizontal, 20)
        }
    }
    private func collectionHeading(_ title: String, tracks: [Track], kind: String) -> some View {
        HStack { Text(title).font(.largeTitle.bold()); Spacer(); Menu {
            Button("Скачать всё", systemImage: "arrow.down.to.line") { Task { await store.download(tracks) } }
            Button("Поделиться", systemImage: "square.and.arrow.up") { Task { shareURL = await store.share(kind: kind); showShare = shareURL != nil } }
        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).glass() } }
    }
}

struct TrackList: View {
    @EnvironmentObject var store: MusicStore
    let tracks: [Track]
    var playlist: Playlist? = nil
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if tracks.isEmpty { Text(store.account == nil && store.screen != .offline ? "Войди в аккаунт или открой офлайн-файлы" : "Здесь пока нет треков").foregroundStyle(.secondary).padding(.top, 30) }
                ForEach(tracks) { track in NativeTrackRow(track: track, queue: tracks, status: store.clock.status, playlist: playlist) }
            }
        }.scrollDismissesKeyboard(.interactively)
    }
}
struct NativeTrackRow: View {
    @EnvironmentObject var store: MusicStore
    let track: Track
    let queue: [Track]
    @ObservedObject var status: TrackStatus
    var playlist: Playlist?
    var body: some View {
        HStack(spacing: 12) {
            Button { store.play(track, in: queue) } label: {
                HStack(spacing: 12) {
                    Cover(track: track, origin: store.origin).frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 5) { Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(2); Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                    Spacer(minLength: 0)
                    if status.id == track.id { PlayingIndicator(playing: status.playing).frame(width: 20, height: 20) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            Menu {
                Button(store.likes.contains(track.id) ? "Убрать из избранного" : "В избранное", systemImage: store.likes.contains(track.id) ? "heart.fill" : "heart") { Task { await store.like(track) } }
                Button("Скачать", systemImage: "arrow.down.to.line") { Task { await store.download([track]) } }
                ShareLink(item: store.origin.appendingPathComponent("track/" + track.id)) { Label("Поделиться", systemImage: "square.and.arrow.up") }
                Menu("Добавить в плейлист") { ForEach(store.playlists) { p in Button(p.name) { Task { await store.add(track, playlist: p) } } } }
                if let playlist { Button("Убрать из плейлиста", role: .destructive) { Task { await store.add(track, playlist: playlist, remove: true) } } }
            } label: { Image(systemName: "ellipsis").frame(width: 34, height: 44) }
        }.padding(12).background(status.id == track.id ? pumpkin.opacity(0.12) : .white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct Cover: View {
    let track: Track?
    let origin: URL
    var body: some View {
        AsyncImage(url: track?.cover_url.flatMap { URL(string: $0, relativeTo: origin) }) { image in image.resizable().scaledToFill() } placeholder: { ZStack { Color.purple.opacity(0.2); Image(systemName: "music.note").font(.title).foregroundStyle(.white.opacity(0.7)) } }.clipped()
    }
}
struct PlayingIndicator: View {
    let playing: Bool
    @Environment(\.scenePhase) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !playing || reduced || scene != .active)) { context in
            HStack(alignment: .center, spacing: 2) { ForEach(0..<4) { i in Capsule().fill(pumpkin).frame(width: 3, height: playing ? CGFloat(5 + 13 * abs(sin(context.date.timeIntervalSinceReferenceDate * 5 + Double(i)))) : 5) } }
        }.accessibilityLabel(playing ? "Сейчас играет" : "На паузе")
    }
}
struct PlaylistScreen: View {
    @EnvironmentObject var store: MusicStore
    let close: () -> Void
    let playlist: Playlist
    @State private var tracks: [Track] = []
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                HStack {
                    Button { close() } label: { Image(systemName: "xmark").frame(width: 44, height: 44).glass(24) }
                    Spacer()
                    Button { Task { await store.download(tracks) } } label: { Image(systemName: "arrow.down.to.line").frame(width: 44, height: 44).glass(24) }
                }
                HStack { Text(playlist.name).font(.largeTitle.bold()); Spacer() }
                TrackList(tracks: tracks, playlist: playlist)
            }.padding(.horizontal, 20).padding(.top, 12)
        }.tint(pumpkin).task { do { tracks = try await store.playlistTracks(playlist.id) } catch { store.error = error.localizedDescription } }
    }
}
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
