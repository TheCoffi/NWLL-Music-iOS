import SwiftUI
import Combine

struct SeasonBackground: View {
    var body: some View {
        GeometryReader { box in
            Image(box.size.width > box.size.height ? "SeasonLandscape" : "SeasonPortrait").resizable().scaledToFill().frame(width: box.size.width, height: box.size.height).clipped()
                .overlay(LinearGradient(colors: [.black.opacity(0.2), Color(red: 0.06, green: 0.025, blue: 0.1).opacity(0.48)], startPoint: .top, endPoint: .bottom))
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}
struct RibbonScene: View {
    let playing: Bool
    let flash: Int
    @Environment(\.scenePhase) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var flashDate = Date.distantPast
    @State private var energy = 0.0
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduced || scene != .active)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                draw(context: context, size: size, date: timeline.date)
            }
        }.onChange(of: flash) { _ in flashDate = Date() }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            guard scene == .active else { return }
            let level = playing ? NativePlayer.shared.audioLevel() : 0
            let next = energy + (level - energy) * (level > energy ? 0.55 : 0.2)
            if abs(next - energy) > 0.003 { energy = next }
        }.allowsHitTesting(false)
    }
    private func draw(context: GraphicsContext, size: CGSize, date: Date) {
                let t = reduced ? 0 : date.timeIntervalSinceReferenceDate * (playing ? 0.45 : 0.14)
                let burst = max(0, 1 - date.timeIntervalSince(flashDate) / 0.65)
                let radius = min(size.width * 0.43, size.height * 0.4) * (1 + energy * 0.26)
                for strand in 0..<18 {
                    let lane = Double(strand) / 17 - 0.5
                    var path = Path()
                    for step in 0...72 {
                        let a = Double(step) / 72 * .pi * 2
                        let r: Double = Double(radius) * (1 + lane * 0.22)
                        let px: Double = Double(size.width) / 2 + r * (cos(a) * 0.95 + sin(a * 2 + t) * 0.24)
                        let py: Double = Double(size.height) / 2 + r * (sin(a) * 0.64 + sin(a * 2 - t) * 0.28 + lane * sin(a * 2 + t) * (0.22 + energy * 0.32))
                        let point = CGPoint(x: px, y: py)
                        if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    path.closeSubpath()
                    let color = burst > 0 ? Color(red: 0.84, green: 0.63, blue: 0.43).opacity(0.35 + burst * 0.5) : (strand % 6 == 0 ? Color(red: 0.69, green: 0.56, blue: 0.43).opacity(0.42) : Color(red: 0.58, green: 0.49, blue: 0.68).opacity(0.26 + energy * 0.2))
                    context.stroke(path, with: .color(color), lineWidth: 0.75 + burst * 1.4 + energy * 0.35)
                }
                for ember in 0..<16 {
                    let life = (t * 0.035 + Double(ember) * 0.618).truncatingRemainder(dividingBy: 1)
                    let x = size.width * CGFloat((Double(ember) * 0.7549).truncatingRemainder(dividingBy: 1))
                    let y = size.height * (0.98 - CGFloat(life) * 0.7)
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(pumpkin.opacity(sin(life * .pi) * (0.2 + energy * 0.5))))
                }
                // Three broad, translucent shapes replace repeated full-screen blur passes.
                for i in 0..<3 {
                    let x = size.width * (0.5 + sin(t * 0.15 + Double(i) * 2) * 0.38)
                    let rect = CGRect(x: x - size.width * 0.55, y: size.height * (0.68 + Double(i) * 0.06), width: size.width * 1.1, height: size.height * 0.12)
                    context.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [.purple.opacity(0.06), .clear]), center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: size.width * 0.5))
                }
    }
}
struct NativeHome: View {
    @EnvironmentObject var store: MusicStore
    @ObservedObject var clock: PlaybackClock
    @Binding var backgroundOnly: Bool

    var body: some View {
        GeometryReader { box in
            VStack(alignment: .leading, spacing: 0) {
                Text("H A L L O W E E N   E D I T I O N")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(pumpkin)
                    .padding(.top, 16)
                Text("Твой\nтёмный ритм")
                    .font(.system(size: min(57, box.size.width * 0.145), weight: .bold))
                    .tracking(-1.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(LinearGradient(colors: [.white, nightwellText, pumpkin.opacity(0.88)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: nightwellViolet.opacity(0.55), radius: 13)
                    .padding(.top, 14)

                Spacer(minLength: 25)

                Button {
                    if clock.current == nil { Task { await store.wave() } }
                    else { clock.toggle() }
                } label: {
                    Image(systemName: clock.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 53, weight: .light))
                        .foregroundStyle(pumpkin)
                        .frame(width: 112, height: 112)
                        .shadow(color: pumpkin.opacity(0.28), radius: 24)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .frame(height: 116)

                VStack(spacing: 13) {
                    Button { Task { await store.wave() } } label: {
                        HStack(spacing: 8) {
                            if store.loading { ProgressView().tint(pumpkin) }
                            Text(store.loading ? "Подбираем…" : "Новая подборка")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(pumpkin)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 13)
                        .glass(25)
                    }.disabled(store.loading)
                    Button("Только фон") { backgroundOnly = true }
                        .font(.subheadline)
                        .foregroundStyle(nightwellText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .glass(22)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                Spacer(minLength: max(32, box.size.height * 0.13))
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct MiniPlayer: View {
    @EnvironmentObject var store: MusicStore
    @ObservedObject var clock: PlaybackClock
    let open: () -> Void
    @State private var glow = false
    @State private var slideDirection: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body: some View {
        GeometryReader { box in
            let compact = box.size.width < 350
            HStack(spacing: compact ? 7 : 10) {
                Button(action: open) {
                    HStack(spacing: 7) {
                        Cover(track: clock.current, origin: store.origin).frame(width: compact ? 37 : 42, height: compact ? 37 : 42).clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(clock.current?.title ?? "Выбери трек").font(.system(size: compact ? 12 : 14, weight: .semibold)).lineLimit(1)
                            Text(clock.current?.artist ?? "Nightwell Music").font(.system(size: compact ? 10 : 12)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .id(clock.id)
                    .transition(.asymmetric(
                        insertion: .offset(x: 45 * slideDirection).combined(with: .opacity),
                        removal: .offset(x: -45 * slideDirection).combined(with: .opacity)
                    ))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                .highPriorityGesture(DragGesture(minimumDistance: 18).onEnded { value in
                    if abs(value.translation.width) > 48 && abs(value.translation.width) > abs(value.translation.height) * 1.2 {
                        changeTrack(value.translation.width < 0 ? 1 : -1)
                    }
                })
                HStack(spacing: compact ? 2 : 5) {
                    if let track = clock.current {
                        Button { Task { await store.like(track) } } label: { Image(systemName: store.likes.contains(track.id) ? "heart.fill" : "heart").font(.system(size: 18)).foregroundStyle(pumpkin).frame(width: compact ? 26 : 29, height: 44) }.accessibilityLabel("Избранное")
                    }
                    Button { changeTrack(-1) } label: { Image(systemName: "backward.end").font(.system(size: 17)).frame(width: compact ? 24 : 28, height: 44) }.accessibilityLabel("Предыдущий трек")
                    Button { clock.toggle() } label: { Image(systemName: clock.playing ? "pause" : "play.fill").font(.system(size: 19, weight: .light)).frame(width: compact ? 40 : 42, height: compact ? 40 : 42).overlay(Circle().stroke(pumpkin.opacity(0.9), lineWidth: 1.1)) }.accessibilityLabel(clock.playing ? "Пауза" : "Воспроизвести")
                    Button { changeTrack(1) } label: { Image(systemName: "forward.end").font(.system(size: 17)).frame(width: compact ? 24 : 28, height: 44) }.accessibilityLabel("Следующий трек")
                }.buttonStyle(.plain)
            }.foregroundStyle(.white).padding(.horizontal, 11).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.ultraThinMaterial)
                        .opacity(0.43)
                    LinearGradient(colors: [pumpkin.opacity(0.14), Color.purple.opacity(0.035)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: box.size.width * min(1, max(0, clock.duration > 0 ? clock.position / clock.duration : 0)))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(LinearGradient(colors: [.white.opacity(0.32), pumpkin.opacity(0.26), .white.opacity(0.13)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: pumpkin.opacity(glow ? 0.4 : 0), radius: 18)
        }.frame(height: 68)
        .animation(reduced ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: clock.id)
        .task(id: clock.id) { guard !reduced else { return }; glow = true; try? await Task.sleep(nanoseconds: 80_000_000); guard !Task.isCancelled else { return }; withAnimation(.easeOut(duration: 0.9)) { glow = false } }
        // Swipe wins over the artwork/title tap, so it never opens the full player.
    }
    private func changeTrack(_ step: Int) {
        slideDirection = step < 0 ? -1 : 1
        NativePlayer.shared.step(step)
    }
}

struct FullPlayer: View {
    @EnvironmentObject var store: MusicStore
    @ObservedObject var clock: PlaybackClock
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var seeking = false
    @State private var scrub = 0.0
    @State private var repeatMode = 0
    @State private var shuffle = false
    var body: some View {
        ZStack {
            SeasonBackground()
            VStack(spacing: 20) {
                HStack { Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44).glass() }; Spacer(); VStack(spacing: 5) { Text("HALLOWEEN EDITION").font(.caption2).tracking(3).foregroundStyle(pumpkin); Text("Играет сейчас").font(.headline) }; Spacer(); tools }
                GeometryReader { box in
                    Group {
                        if showLyrics { SharedLyricsPanel(model: store.lyrics, clock: clock) }
                        else { Cover(track: clock.current, origin: store.origin).frame(width: min(box.size.width, box.size.height), height: min(box.size.width, box.size.height)).clipShape(RoundedRectangle(cornerRadius: 26)).frame(maxWidth: .infinity, maxHeight: .infinity) }
                    }.contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.22)) { showLyrics.toggle() } }
                    .highPriorityGesture(DragGesture(minimumDistance: 18).onEnded { value in
                        let dx = value.translation.width
                        if abs(dx) > 52 && abs(dx) > abs(value.translation.height) * 1.15 {
                            NativePlayer.shared.step(dx < 0 ? 1 : -1)
                        } else if value.translation.height > 85 && value.translation.height > abs(dx) * 1.2 {
                            dismiss()
                        }
                    })
                }
                HStack { VStack(alignment: .leading, spacing: 8) { Text(clock.current?.title ?? "Выбери трек").font(.title2.bold()).lineLimit(2); Text(clock.current?.artist ?? "").font(.body).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); if let track = clock.current { Button { Task { await store.like(track) } } label: { Image(systemName: store.likes.contains(track.id) ? "heart.fill" : "heart").font(.title).foregroundStyle(pumpkin) } } }
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Slider(value: Binding(get: { seeking ? scrub : min(clock.position, clock.duration) }, set: { scrub = $0 }), in: 0...clock.duration) { editing in if editing { scrub = clock.position; seeking = true } else { NativePlayer.shared.seek(scrub); seeking = false } }
                        HStack { Text(formatTime(seeking ? scrub : clock.position)); Spacer(); Text(formatTime(clock.duration)) }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    HStack {
                        Button { shuffle.toggle(); NativePlayer.shared.modes(repeatMode: repeatMode, shuffle: shuffle) } label: { Image(systemName: "shuffle").foregroundStyle(shuffle ? pumpkin : .secondary) }; Spacer()
                        Button { NativePlayer.shared.step(-1) } label: { Image(systemName: "backward.end") }; Spacer()
                        Button { clock.toggle() } label: { Image(systemName: clock.playing ? "pause" : "play.fill").font(.system(size: 32)).frame(width: 74, height: 74).overlay(Circle().stroke(pumpkin, lineWidth: 1)) }; Spacer()
                        Button { NativePlayer.shared.step(1) } label: { Image(systemName: "forward.end") }; Spacer()
                        Button { repeatMode = (repeatMode + 1) % 3; NativePlayer.shared.modes(repeatMode: repeatMode, shuffle: shuffle) } label: { Image(systemName: repeatMode == 2 ? "repeat.1" : "repeat").foregroundStyle(repeatMode > 0 ? pumpkin : .secondary) }
                    }.font(.title2)
                    Divider()
                    Button { showQueue = true } label: { HStack { Image(systemName: "list.bullet"); Text("Дальше в очереди"); Spacer(); Text(String(clock.queue.count)).foregroundStyle(.secondary) } }.font(.subheadline)
                }.padding(20).glass(28)
                if !clock.failure.isEmpty { Text(clock.failure).font(.caption).foregroundStyle(pumpkin) }
            }.padding(.horizontal, 22).padding(.vertical, 12)
        }.overlay { NativeFogLayer(active: !showQueue) }.tint(pumpkin)
        .onAppear {
            let modes = NativePlayer.shared.snapshot(includeQueue: false)
            repeatMode = modes["repeat"] as? Int ?? 0; shuffle = modes["shuffle"] as? Bool ?? false
            if store.lyrics.value == nil || store.lyrics.value?.status == "error" || store.lyrics.value?.status == "unavailable" {
                store.lyrics.select(clock.current, api: store.api, origin: store.origin, online: store.account != nil)
            }
        }
        .sheet(isPresented: $showQueue) { NavigationStack { TrackList(tracks: clock.queue).padding().navigationTitle("Очередь").toolbar { Button("Закрыть") { showQueue = false } } } }
        .simultaneousGesture(DragGesture(minimumDistance: 20, coordinateSpace: .global).onEnded { value in
            let dx = value.translation.width
            let dy = value.translation.height
            if dy > 85 && dy > abs(dx) * 1.2 {
                dismiss()
            } else if abs(dx) > 75 && abs(dx) > abs(dy) * 1.3 {
                NativePlayer.shared.step(dx < 0 ? 1 : -1)
            }
        })
    }
    private var tools: some View {
        Menu {
            Button(showLyrics ? "Обложка" : "Текст песни", systemImage: "text.alignleft") { showLyrics.toggle() }
            if let track = clock.current {
                Button("Скачать", systemImage: "arrow.down.to.line") { Task { await store.download([track]) } }
                ShareLink(item: store.origin.appendingPathComponent("track/" + track.id)) { Label("Поделиться", systemImage: "square.and.arrow.up") }
                Menu("Добавить в плейлист") { ForEach(store.playlists) { p in Button(p.name) { Task { await store.add(track, playlist: p) } } } }
            }
        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).glass() }
    }
}
func formatTime(_ seconds: Double) -> String { let value = seconds.isFinite ? max(0, Int(seconds)) : 0; return String(format: "%d:%02d", value / 60, value % 60) }
struct LyricsView: View {
    let lyrics: Lyrics?
    let position: Double
    var active: Int { (lyrics?.lines ?? []).lastIndex { $0.time <= position } ?? -1 }
    var body: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center, spacing: 25) {
                    if let lyrics {
                        if lyrics.synced == true, let lines = lyrics.lines {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                Text(line.text)
                                    .font(.system(size: index == active ? 32 : 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(index == active ? nightwellText : Color.white.opacity(0.27))
                                    .shadow(color: index == active ? nightwellText.opacity(0.32) : .clear, radius: 8)
                                    .shadow(color: index == active ? nightwellViolet : .clear, radius: 22)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .id(index)
                            }
                        } else {
                            Text(lyrics.plain ?? lyrics.message ?? (lyrics.searching ? "Ищем текст…" : "Текст пока не найден"))
                                .font(.system(size: 25, weight: .semibold))
                                .foregroundStyle(nightwellText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(10)
                        }
                        Text(lyrics.source ?? "").font(.caption).foregroundStyle(.secondary)
                    } else { ProgressView("Ищем текст…") }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
            .onAppear { if active >= 0 { DispatchQueue.main.async { reader.scrollTo(active, anchor: .center) } } }
            .onChange(of: active) { next in
                guard next >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.3)) { reader.scrollTo(next, anchor: .center) }
            }
        }
    }
}

struct AuthSheet: View {
    let close: () -> Void
    @EnvironmentObject var store: MusicStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var register = false
    @State private var busy = false
    @State private var failure = ""

    var body: some View {
        ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 9) {
                                Image("BrandLogo").resizable().scaledToFit().frame(width: 56, height: 56)
                                Text(register ? "Создать аккаунт" : "С возвращением")
                                    .font(.system(size: 31, weight: .bold))
                                Text(register ? "Создай аккаунт Nightwell Music" : "Твоя музыка снова рядом")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { close() } label: {
                                Image(systemName: "xmark").font(.headline)
                                    .frame(width: 42, height: 42).glass(21)
                            }
                        }
                        VStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Email").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                TextField("name@example.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.username)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .padding(15)
                                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            }
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Пароль").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                SecureField("Пароль", text: $password)
                                    .textContentType(register ? .newPassword : .password)
                                    .padding(15)
                                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }.padding(16).glass(25)
                        if !failure.isEmpty {
                            Text(failure).font(.subheadline).foregroundStyle(.orange)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                        }
                        Button {
                            guard !busy else { return }
                            busy = true
                            Task {
                                let ok = await store.authenticate(email: email, password: password, register: register)
                                busy = false
                                if ok { close() }
                                else { failure = store.error ?? "Не удалось войти"; store.error = nil }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if busy { ProgressView().tint(.black) }
                                Text(register ? "Создать аккаунт" : "Войти")
                                    .font(.headline)
                                Spacer()
                            }
                            .frame(height: 54)
                            .foregroundStyle(Color.black)
                            .background(pumpkin, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .disabled(busy || email.isEmpty || password.isEmpty)
                        .opacity(busy || email.isEmpty || password.isEmpty ? 0.5 : 1)
                        Button(register ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Создать") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                register.toggle()
                                failure = ""
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(pumpkin)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                }
        }
        .tint(pumpkin)
    }
}

struct NativeSettings: View {
    let close: () -> Void
    @EnvironmentObject var store: MusicStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("nw-transition-seconds") private var transition = 0.8
    @AppStorage("nw-ambient-lyrics") private var ambientLyrics = true
    var body: some View {
        VStack(spacing: 14) {
            HStack { Text("Настройки").font(.title.bold()); Spacer(); Button { close() } label: { Image(systemName: "xmark").frame(width: 40, height: 40).glass(20) } }
            Form {
                Section("Оформление") { Toggle("Текст вместе с лентами", isOn: $ambientLyrics).onChange(of: ambientLyrics) { enabled in if enabled { store.lyrics.select(store.clock.current, api: store.api, origin: store.origin, online: store.account != nil) } }; Text("Строки с таймкодами появляются по времени песни.").font(.caption).foregroundStyle(.secondary) }
                Section("Воспроизведение") { HStack { Text("Переход между треками"); Spacer(); Text(transition == 0 ? "Выкл." : String(format: "%.1f с", transition)).foregroundStyle(pumpkin) }; Slider(value: $transition, in: 0...5, step: 0.1).onChange(of: transition) { NativePlayer.shared.transitionDuration($0) }; Text("Плавное затухание и нарастание громкости. 0 — без перехода.").font(.caption).foregroundStyle(.secondary) }
                Section { Text("Nightwell Music · нативный интерфейс").font(.caption).foregroundStyle(.secondary) }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(maxHeight: 350)
        }.padding(20).tint(pumpkin)
    }
}
