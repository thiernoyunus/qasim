import AppKit
import SwiftUI

/// The "regular" new-session screen shown after onboarding is complete. Task,
/// mode, list and duration all live on one screen; the app/site list opens as
/// a sub-screen. The onboarding wizard is a separate panel (SetupView).
struct NewSessionView: View {
    @Environment(AppModel.self) private var model
    @State private var editingList = false
    @State private var showModes = false
    @State private var query = ""
    @State private var highlighted = 0
    @State private var customMinutes: String = ""
    @State private var showCustomInput = false
    @FocusState private var taskFieldFocused: Bool

    private let presetMinutes = [5, 10, 15, 20, 25, 30, 45, 50, 60, 90]

    /// Allow mode with an empty list would count every app as a distraction the
    /// moment the session starts.
    private var needsAllowedItems: Bool {
        let session = model.session
        return session.strategy == .allow
            && session.allowedApps.isEmpty
            && session.allowedSites.isEmpty
    }

    var body: some View {
        let session = model.session

        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CompanionVisibilityNotice()
                    if editingList {
                        listEditor(session: session)
                    } else {
                        taskSection(session: session)
                        modeSection(session: session)
                        durationSection(session: session)
                    }
                }
                .padding(22)
            }
            footer(session: session)
        }
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(model.prefs.companion.assetName(for: .idle))
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.prefs.companion.displayName)
                    .font(Typeface.display(28))
                    .foregroundStyle(Palette.ink)
                Text("One thing. Or the lights go out.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Button("Customize") {
                model.openSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.inkSoft)
            .accessibilityLabel("Customize")
            Button(model.isPreviewing ? "Stop preview" : "Preview") {
                model.togglePreview()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.emberText)
            .accessibilityLabel(model.isPreviewing ? "Stop preview" : "Preview")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Palette.inkSoft)
    }

    /// The bordered box every field on this screen sits in.
    private func box<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.ink, lineWidth: 1.5)
            )
    }

    private func taskSection(session: SessionController) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Task to complete")
            box {
                TextField("Write chapter 2", text: Bindable(session).taskTitle)
                    .focused($taskFieldFocused)
                    .onAppear {
                        // The NSPanel becomes key just after SwiftUI appears, so focus
                        // on the next run-loop instead of losing it to the window.
                        DispatchQueue.main.async { taskFieldFocused = true }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(12)
            }
        }
    }

    private func modeIcon(_ strategy: FocusStrategy) -> String {
        switch strategy {
        case .allow: "checkmark.shield"
        case .block: "shield.lefthalf.filled"
        case .company: "shield"
        }
    }

    private func modeSection(session: SessionController) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Mode")
            box {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showModes.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: modeIcon(session.strategy))
                        Text(session.strategy.title).font(.system(size: 15, weight: .medium))
                        Spacer()
                        Image(systemName: showModes ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mode: \(session.strategy.title)")

                if showModes {
                    Divider().overlay(Palette.ink.opacity(0.15))
                    ForEach(FocusStrategy.allCases) { strategy in
                        modeOption(strategy, session: session)
                    }
                }

                if session.strategy != .company {
                    Divider().overlay(Palette.ink.opacity(0.15))
                    listRow(session: session)
                }
            }

            HStack {
                Text("Temper")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
                Picker("Temper", selection: Bindable(session).temper) {
                    ForEach(Temper.allCases) { temper in
                        Text(temper.title).tag(temper)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private func modeOption(_ strategy: FocusStrategy, session: SessionController) -> some View {
        let selected = session.strategy == strategy
        return Button {
            session.strategy = strategy
            withAnimation(.easeOut(duration: 0.15)) { showModes = false }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: modeIcon(strategy)).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(strategy.title).font(.system(size: 14, weight: .semibold))
                    Text(strategy.blurb)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
            }
            .padding(12)
            .background(selected ? Palette.ink.opacity(0.05) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Shows what's picked (as logos) and opens the list editor.
    private func listRow(session: SessionController) -> some View {
        let apps = session.strategy == .allow ? session.allowedApps : session.blockedApps
        let picked = sites(session)
        let total = apps.count + picked.count
        return Button {
            query = ""
            editingList = true
        } label: {
            HStack(spacing: 6) {
                if total == 0 {
                    Text(session.strategy == .allow ? "Add allowed apps and sites" : "Add blocked apps and sites")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.inkSoft)
                } else {
                    ForEach(apps.prefix(6)) { app in
                        Image(nsImage: model.catalog.icon(for: app)).resizable().frame(width: 20, height: 20)
                    }
                    ForEach(picked.prefix(max(0, 6 - apps.count))) { site in
                        SiteIcon(host: site.host).frame(width: 18, height: 18)
                    }
                    if total > 6 {
                        Text("+\(total - 6)").font(.system(size: 12, weight: .semibold))
                    }
                }
                Spacer()
                Image(systemName: "pencil").font(.system(size: 13, weight: .semibold))
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(total == 0 ? "Add apps and sites" : "Edit apps and sites, \(total) picked")
    }

    private func durationLabel(_ session: SessionController) -> String {
        session.isStopwatch ? "Stopwatch" : "\(session.durationMinutes) minutes"
    }

    private func durationSection(session: SessionController) -> some View {
        @Bindable var prefs = model.prefs
        return VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Duration")
            Menu {
                ForEach(presetMinutes, id: \.self) { minutes in
                    Button("\(minutes) minutes") {
                        session.durationMinutes = minutes
                        showCustomInput = false
                    }
                }
                Divider()
                Button("Stopwatch (counts up)") {
                    session.durationMinutes = 0
                    showCustomInput = false
                }
                Button("Custom\u{2026}") {
                    showCustomInput = true
                    if session.durationMinutes <= 0 { session.durationMinutes = 25 }
                    customMinutes = "\(session.durationMinutes)"
                }
            } label: {
                box {
                    HStack {
                        Text(durationLabel(session)).font(.system(size: 15))
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .accessibilityLabel("Duration: \(durationLabel(session))")

            if showCustomInput {
                HStack(spacing: 8) {
                    TextField("Minutes", text: $customMinutes)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: 80)
                        .padding(10)
                        .background(Palette.cream, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Palette.ink.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: customMinutes) { _, raw in
                            if let mins = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                               mins > 0, mins <= 600 {
                                session.durationMinutes = mins
                            }
                        }
                    Text("minutes (1\u{2013}600)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkSoft)
                }
            }

            Stepper(value: $prefs.breakMinutes, in: 1...30) {
                Text("Break: \(prefs.breakMinutes) minute\(prefs.breakMinutes == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
            }
            .onChange(of: prefs.breakMinutes) { _, _ in prefs.save() }
            .padding(.top, 4)
        }
        .onAppear {
            if session.durationMinutes > 0, !presetMinutes.contains(session.durationMinutes) {
                showCustomInput = true
                customMinutes = "\(session.durationMinutes)"
            }
        }
    }

    private func listEditor(session: SessionController) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                editingList = false
            } label: {
                Label("Back", systemImage: "arrow.left").font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)

            Text(session.strategy == .allow ? "What do you actually need?" : "What\u{2019}s off limits?")
                .font(Typeface.display(22))
                .foregroundStyle(Palette.ink)

            Text(session.strategy == .allow
                ? "Everything you don\u{2019}t pick here counts as a distraction."
                : "Anything you pick here counts as a distraction. Everything else is fine.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Search apps or type a website", text: $query)
                .textFieldStyle(.plain)
                .onSubmit {
                    let list = suggestionList
                    if list.indices.contains(highlighted) { pick(list[highlighted], session: session) }
                }
                .onKeyPress(.downArrow) {
                    highlighted = min(highlighted + 1, max(suggestionList.count - 1, 0))
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    highlighted = max(highlighted - 1, 0)
                    return .handled
                }
                .onChange(of: query) { _, _ in highlighted = 0 }
                .padding(10)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Palette.ink.opacity(0.2), lineWidth: 1)
                )

            suggestions(session: session)

            pickedChips(session: session)
        }
    }

    private func footer(session: SessionController) -> some View {
        Group {
            if editingList {
                Button("Done") { editingList = false }
                    .buttonStyle(InkButtonStyle())
                    .keyboardShortcut(.cancelAction)
            } else {
                let startTitle = model.isEditingSession ? "Save changes" : "Start"
                VStack(spacing: 6) {
                    if needsAllowedItems {
                        Text("Pick at least one app or site you need")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Button {
                        if session.taskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            session.taskTitle = "The one thing"
                        }
                        if model.isEditingSession {
                            model.saveSessionEdits()
                        } else {
                            model.beginSession()
                        }
                    } label: {
                        Text(startTitle).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(needsAllowedItems)
                    .opacity(needsAllowedItems ? 0.4 : 1)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel(startTitle)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Palette.paperDeep.opacity(0.5))
    }

    private enum Suggestion: Identifiable {
        case site(SiteRule, kind: String)
        case app(AppIdentity)

        var id: String {
            switch self {
            case .site(let rule, let kind): "\(kind):\(rule.id)"
            case .app(let app): "app:\(app.id)"
            }
        }
    }

    /// One list for both kinds, like a search bar: the typed website (and the
    /// exact page, for a full link), popular sites by name, then matching apps.
    private var suggestionList: [Suggestion] {
        let raw = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }
        var list: [Suggestion] = []
        let typed = raw.replacingOccurrences(of: " ", with: "")
        if typed.contains("."), let page = BrowserInspector.page(from: typed) {
            list.append(.site(SiteRule(host: page.host), kind: "Website"))
            if page.path.count > 1 {
                list.append(.site(SiteRule(host: page.host, path: page.path), kind: "Single page"))
            }
        }
        for brand in SiteBrand.matching(raw).prefix(3) where !list.contains(where: { $0.id == "Website:\(brand.hosts[0])" }) {
            list.append(.site(SiteRule(host: brand.hosts[0]), kind: "Website"))
        }
        list += model.catalog.search(raw).prefix(8).map { .app($0) }
        return list
    }

    private func pick(_ suggestion: Suggestion, session: SessionController) {
        switch suggestion {
        case .site(let rule, _):
            addSite(rule, session: session)
        case .app(let app):
            toggle(app, session: session)
        }
        query = ""
    }

    @ViewBuilder
    private func suggestions(session: SessionController) -> some View {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            let list = suggestionList
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, suggestion in
                    switch suggestion {
                    case .site(let rule, let kind):
                        suggestionRow(kind: kind, selected: sites(session).contains(rule), highlighted: index == highlighted) {
                            SiteIcon(host: rule.host)
                        } title: {
                            kind == "Website" ? (SiteBrand.forHost(rule.host)?.name).map { "\($0) \u{00B7} \(rule.host)" } ?? rule.host : rule.id
                        } action: {
                            pick(suggestion, session: session)
                        }
                    case .app(let app):
                        suggestionRow(kind: "App", selected: contains(app, session: session), highlighted: index == highlighted) {
                            Image(nsImage: model.catalog.icon(for: app)).resizable()
                        } title: {
                            app.name
                        } action: {
                            pick(suggestion, session: session)
                        }
                    }
                }
                if list.isEmpty {
                    Text(model.catalog.isLoading
                        ? "Loading your apps\u{2026}"
                        : "No apps match. For a website, type the full address, like youtube.com.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(10)
                }
            }
            .padding(4)
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Palette.ink.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private func suggestionRow<Icon: View>(
        kind: String,
        selected: Bool,
        highlighted: Bool,
        @ViewBuilder icon: () -> Icon,
        title: () -> String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon().frame(width: 20, height: 20)
                Text(title())
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if selected {
                    Image(systemName: "checkmark").foregroundStyle(Palette.ember)
                }
                Text(kind)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(highlighted ? Palette.ink.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Everything picked so far, apps and websites together, each with its logo.
    private func pickedChips(session: SessionController) -> some View {
        let apps = session.strategy == .allow ? session.allowedApps : session.blockedApps
        return FlexibleStack {
            ForEach(apps) { app in
                pickedChip(app.name) {
                    Image(nsImage: model.catalog.icon(for: app)).resizable()
                } remove: {
                    remove(app, session: session)
                }
            }
            ForEach(sites(session)) { site in
                pickedChip(site.id) {
                    SiteIcon(host: site.host)
                } remove: {
                    session.allowedSites.removeAll { $0 == site }
                    session.blockedSites.removeAll { $0 == site }
                }
            }
        }
    }

    private func pickedChip<Icon: View>(
        _ title: String,
        @ViewBuilder icon: () -> Icon,
        remove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            icon().frame(width: 16, height: 16)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 260, alignment: .leading)
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(title)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Palette.cream, in: Capsule())
        .overlay(Capsule().stroke(Palette.ink.opacity(0.2), lineWidth: 1))
        .foregroundStyle(Palette.ink)
    }

    private func sites(_ session: SessionController) -> [SiteRule] {
        session.strategy == .allow ? session.allowedSites : session.blockedSites
    }

    private func toggle(_ app: AppIdentity, session: SessionController) {
        if session.strategy == .allow {
            if let i = session.allowedApps.firstIndex(of: app) {
                session.allowedApps.remove(at: i)
            } else {
                session.allowedApps.append(app)
            }
        } else {
            if let i = session.blockedApps.firstIndex(of: app) {
                session.blockedApps.remove(at: i)
            } else {
                session.blockedApps.append(app)
            }
        }
    }

    private func remove(_ app: AppIdentity, session: SessionController) {
        session.allowedApps.removeAll { $0 == app }
        session.blockedApps.removeAll { $0 == app }
    }

    private func contains(_ app: AppIdentity, session: SessionController) -> Bool {
        session.strategy == .allow ? session.allowedApps.contains(app) : session.blockedApps.contains(app)
    }

    private func addSite(_ rule: SiteRule, session: SessionController) {
        if session.strategy == .allow {
            if !session.allowedSites.contains(rule) { session.allowedSites.append(rule) }
        } else {
            if !session.blockedSites.contains(rule) { session.blockedSites.append(rule) }
        }
    }
}

/// A website's logo, fetched from the site itself (no third-party icon service
/// learns what the user blocks). Falls back to the first letter.
struct SiteIcon: View {
    let host: String

    var body: some View {
        AsyncImage(url: URL(string: "https://\(host)/favicon.ico")) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFit()
            } else {
                Text(String(host.first ?? "?").uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.emberText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.ember.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
