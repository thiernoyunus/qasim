import AppKit
import SwiftUI

/// The "regular" new-session flow shown after onboarding is complete.
/// task -> mode -> apps/sites -> duration+break. No Back button: there's nothing
/// behind it. The onboarding wizard is a separate panel (SetupView).
struct NewSessionView: View {
    @Environment(AppModel.self) private var model
    @State private var step: Int = 0
    @State private var query = ""
    @State private var siteDraft = ""
    @State private var customMinutes: String = ""
    @State private var showCustomInput = false

    private let totalSteps = 4
    private let appsStep = 2

    var body: some View {
        @Bindable var session = model.session
        @Bindable var prefs = model.prefs

        VStack(spacing: 0) {
            header
            stepDots
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CompanionVisibilityNotice()

                    switch step {
                    case 0: taskStepView(session: session)
                    case 1: strategyStepView(session: session)
                    case appsStep: appsStepView(session: session)
                    default: durationStepView(session: session)
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
            .foregroundStyle(Palette.ember)
            .accessibilityLabel(model.isPreviewing ? "Stop preview" : "Preview")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Palette.ember : Palette.ink.opacity(0.15))
                    .frame(width: i == step ? 22 : 8, height: 8)
            }
        }
        .padding(.bottom, 4)
    }

    private func taskStepView(session: SessionController) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What should you be doing?")
                .font(Typeface.display(22))
                .foregroundStyle(Palette.ink)
            Text("One thing. Be specific. \u{201C}Be productive\u{201D} doesn\u{2019}t count.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSoft)
            TextField("Write chapter 2", text: Bindable(session).taskTitle)
                .textFieldStyle(.plain)
                .font(Typeface.display(20))
                .padding(14)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Palette.ink, lineWidth: 2)
                )
        }
    }

    private func strategyStepView(session: SessionController) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mode")
                .font(Typeface.display(22))
                .foregroundStyle(Palette.ink)
            ForEach(FocusStrategy.allCases) { strategy in
                Button {
                    session.strategy = strategy
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: session.strategy == strategy ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(session.strategy == strategy ? Palette.ember : Palette.inkSoft)
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(strategy.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text(strategy.blurb)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(session.strategy == strategy ? Palette.ink : Palette.ink.opacity(0.15), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }

            Text("Temper")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 6)
            Picker("Temper", selection: Bindable(session).temper) {
                ForEach(Temper.allCases) { temper in
                    Text(temper.title).tag(temper)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func appsStepView(session: SessionController) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.strategy == .company {
                Text("No list needed.")
                    .font(Typeface.display(22))
                Text("Wick will just sit with you and live its little life.")
                    .foregroundStyle(Palette.inkSoft)
            } else {
                Text(session.strategy == .allow ? "What do you actually need?" : "What\u{2019}s off limits?")
                    .font(Typeface.display(22))
                    .foregroundStyle(Palette.ink)

                chipRow(session: session)

                TextField("Search apps", text: $query)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Palette.cream, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Palette.ink.opacity(0.2), lineWidth: 1)
                    )

                appList(session: session)

                HStack {
                    TextField("Add a site, like youtube.com", text: $siteDraft)
                        .textFieldStyle(.plain)
                        .onSubmit { addSite(session: session) }
                    Button("Add") { addSite(session: session) }
                        .buttonStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(10)
                .background(Palette.cream, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                siteChips(session: session)
            }
        }
    }

    private func durationStepView(session: SessionController) -> some View {
        @Bindable var prefs = model.prefs
        return VStack(alignment: .leading, spacing: 12) {
            Text("Focus session")
                .font(Typeface.display(22))
            let options = [5, 10, 15, 20, 25, 30, 45, 50, 60, 90, 0]
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.self) { minutes in
                    Button {
                        session.durationMinutes = minutes
                        if minutes == 0 {
                            showCustomInput = true
                            if customMinutes.isEmpty { customMinutes = "25" }
                        } else {
                            showCustomInput = false
                        }
                    } label: {
                        Text(minutes == 0 ? "Custom" : "\(minutes)m")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(session.durationMinutes == minutes ? Palette.ink : Palette.cream)
                            .foregroundStyle(session.durationMinutes == minutes ? Palette.cream : Palette.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
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
                    Button("Stopwatch") {
                        session.durationMinutes = 0
                        customMinutes = ""
                        showCustomInput = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                }
            }

            Text("Break length")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 6)
            Stepper(value: $prefs.breakMinutes, in: 1...30) {
                Text("\(prefs.breakMinutes) minute\(prefs.breakMinutes == 1 ? "" : "s")")
                    .foregroundStyle(Palette.ink)
            }
            .onChange(of: prefs.breakMinutes) { _, _ in prefs.save() }
        }
    }

    private func footer(session: SessionController) -> some View {
        HStack {
            // No Back button: this is the regular flow, not the onboarding wizard.
            // Hiding it makes the panel feel finished, not partial.
            Spacer()
            if step < totalSteps - 1 {
                Button(step == appsStep && session.strategy == .company ? "Skip" : "Next") {
                    if step == 0 && session.taskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        session.taskTitle = "The one thing"
                    }
                    step += 1
                }
                .buttonStyle(InkButtonStyle())
                .accessibilityLabel(step == appsStep && session.strategy == .company ? "Skip" : "Next")
            } else {
                Button(model.isEditingSession ? "Save changes" : "Start") {
                    if model.isEditingSession {
                        model.saveSessionEdits()
                    } else {
                        model.beginSession()
                    }
                }
                .disabled(session.taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel(model.isEditingSession ? "Save changes" : "Start")
            }
        }
        .padding(18)
        .background(Palette.paperDeep.opacity(0.5))
    }

    private func chipRow(session: SessionController) -> some View {
        let selected = session.strategy == .allow ? session.allowedApps : session.blockedApps
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(selected) { app in
                    HStack(spacing: 6) {
                        Text(app.name).font(.system(size: 12, weight: .medium))
                        Button {
                            remove(app, session: session)
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Palette.ink, in: Capsule())
                    .foregroundStyle(Palette.cream)
                }
            }
        }
    }

    private func siteChips(session: SessionController) -> some View {
        let sites = session.strategy == .allow ? session.allowedSites : session.blockedSites
        return FlowWrap(items: sites) { site in
            HStack(spacing: 4) {
                Text(site.host).font(.system(size: 11, weight: .medium))
                Button {
                    if session.strategy == .allow {
                        session.allowedSites.removeAll { $0 == site }
                    } else {
                        session.blockedSites.removeAll { $0 == site }
                    }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Palette.ember.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Palette.ember.opacity(0.4), lineWidth: 1))
        }
    }

    private func appList(session: SessionController) -> some View {
        let matches = model.catalog.search(query).prefix(query.isEmpty ? 30 : 60)
        return VStack(spacing: 0) {
            ForEach(Array(matches)) { app in
                Button {
                    toggle(app, session: session)
                } label: {
                    HStack(spacing: 10) {
                        Image(nsImage: model.catalog.icon(for: app))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(app.name)
                            .foregroundStyle(Palette.ink)
                            .font(.system(size: 13))
                        Spacer()
                        if contains(app, session: session) {
                            Image(systemName: "checkmark").foregroundStyle(Palette.ember)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
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

    private func addSite(session: SessionController) {
        guard let host = SiteRule.normalize(siteDraft) else { return }
        let rule = SiteRule(host: host)
        if session.strategy == .allow {
            if !session.allowedSites.contains(rule) { session.allowedSites.append(rule) }
        } else {
            if !session.blockedSites.contains(rule) { session.blockedSites.append(rule) }
        }
        siteDraft = ""
    }
}
