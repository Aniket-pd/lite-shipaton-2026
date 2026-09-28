import SwiftData
import SwiftUI

struct CreateAppView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = CreateAppViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingAllFavorites = false
    @State private var address = ""
    @State private var addressError: String?
    @State private var path: [String] = []
    private let didCreate: () -> Void

    init(initialService: CatalogService? = nil, didCreate: @escaping () -> Void = {}) {
        self.didCreate = didCreate
        guard let initialService, let url = URL(string: initialService.address) else { return }
        let preparedModel = CreateAppViewModel()
        preparedModel.configure(url: url, service: initialService)
        _model = State(initialValue: preparedModel)
        _path = State(initialValue: ["details"])
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Choose a website or paste a link.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        addressEntry
                    }
                    favorites
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Lite App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { cancelButton }
                        .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .confirmationAction) { nextButton }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { cancelButton }
                    ToolbarItem(placement: .confirmationAction) { nextButton }
                }
            }
            .navigationDestination(for: String.self) { _ in
                CreateAppDetailsView(model: model) {
                    didCreate()
                    dismiss()
                }
            }
        }
        .onDisappear { model.biometrics.cancel() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.biometrics.cancel() }
        }
    }

    private var validatedAddress: URL? {
        guard let url = try? WebsiteURL.normalized(address), let host = url.host,
              host.contains(".") || host.contains(":") || host == "localhost" else { return nil }
        return url
    }

    private var canContinue: Bool { validatedAddress != nil }

    private var cancelButton: some View {
        CreationToolbarButton(title: "Cancel", action: { dismiss() })
    }

    private var nextButton: some View {
        CreationToolbarButton(title: "Next", isEnabled: canContinue, isPrimary: true,
                              action: continueWithAddress)
            .accessibilityIdentifier("catalog.continue")
    }

    private var addressEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Website address", text: $address)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit(continueWithAddress)
                    .onChange(of: address) { addressError = nil }
                    .accessibilityLabel("Website address")
                    .accessibilityIdentifier("catalog.url")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 54)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))

            if let addressError {
                Text(addressError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Or choose a favorite")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                               count: dynamicTypeSize.isAccessibilitySize ? 2 : 3),
                spacing: 26
            ) {
                ForEach(showingAllFavorites ? CatalogService.all : Array(CatalogService.all.prefix(5))) { service in
                    Button {
                        guard let url = URL(string: service.address) else { return }
                        model.configure(url: url, service: service)
                        path.append("details")
                    } label: {
                        VStack(spacing: 8) {
                            AppIconView(data: URL(string: service.address).flatMap { CatalogIcon.data(for: $0) },
                                        websiteURL: URL(string: service.address), symbol: service.symbol,
                                        size: 48)
                            Text(service.name)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .top)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("catalog.service.\(service.id)")
                }
                if !showingAllFavorites {
                    Button { showingAllFavorites = true } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "ellipsis")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 48, height: 48)
                                .background(Color(.tertiarySystemFill), in: .circle)
                            Text("More").font(.footnote)
                        }
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .top)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More websites")
                    .accessibilityIdentifier("catalog.more")
                }
            }
        }
    }

    private func continueWithAddress() {
        guard let url = validatedAddress else {
            addressError = WebsiteURL.ValidationError.invalid.localizedDescription
            return
        }
        addressError = nil
        model.configure(url: url, service: nil)
        path.append("details")
    }
}

private struct CreateAppDetailsView: View {
    @Environment(ProStore.self) private var pro
    @Environment(\.modelContext) private var context
    @Bindable var model: CreateAppViewModel
    let didCreate: () -> Void
    @State private var created = false
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var isNameFocused: Bool
    @ScaledMetric(relativeTo: .title3) private var previewSize = 68.0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                preview
                nameSection
                ProfileAppearanceSection("App icon") {
                    ProfileIconPicker(
                        useWebsiteIcon: $model.useWebsiteIcon,
                        symbol: $model.symbol,
                        iconData: model.iconData,
                        websiteURL: model.url,
                        websiteName: model.websiteName,
                        isFetchingIcon: model.isFetchingIcon
                    )
                    .padding(12)
                }
                ProfileAppearanceSection("Badge color") {
                    BadgeColorPicker(color: $model.badgeColor)
                        .padding(12)
                }
                securitySection
                if let error = model.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .disabled(model.isSaving)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("New profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.isSaving)
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .confirmationAction) { createButton }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .confirmationAction) { createButton }
            }
        }
        .interactiveDismissDisabled(model.isSaving)
        .task(id: model.url) { await model.fetchIcon() }
        .onDisappear {
            saveTask?.cancel()
            model.biometrics.cancel()
        }
        .sensoryFeedback(.success, trigger: created)
        .sheet(item: $model.proFeature) { ProPaywallView(feature: $0) }
    }

    private var createButton: some View {
        CreationToolbarButton(title: "Create", isEnabled: model.canCreate,
                              isPrimary: true, isLoading: model.isSaving, action: createProfile)
            .accessibilityIdentifier("creation.create")
    }

    private var preview: some View {
        ProfileCreationPreview(
            iconData: model.useWebsiteIcon ? model.iconData : nil,
            websiteURL: model.url,
            symbol: model.symbol,
            badgeColor: model.badgeColor,
            iconSize: previewSize,
            websiteName: model.websiteName,
            profileName: model.trimmedName.isEmpty ? "Profile" : model.trimmedName
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("creation.preview")
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileAppearanceSection("Profile name") {
                TextField("Personal or Work", text: $model.name)
                    .textInputAutocapitalization(.words)
                    .textContentType(.nickname)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit { isNameFocused = false }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(minHeight: 50)
                    .accessibilityLabel("Profile name")
                    .accessibilityIdentifier("creation.name")
            }
            Text(model.trimmedName.count > 40
                 ? "Choose a profile name with 40 characters or fewer."
                 : "For example, Personal or Work.")
                .font(.footnote)
                .foregroundStyle(model.trimmedName.count > 40 ? Color.red : Color.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $model.isBiometricLocked) {
                Label("Require \(model.biometrics.label)", systemImage: "lock")
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .accessibilityIdentifier("creation.lock")
            Text("Each profile keeps its own sign-in. Tracker blocking is on by default.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private func createProfile() {
        isNameFocused = false
        saveTask = Task {
            if await model.create(in: context, pro: pro) { created = true; didCreate() }
        }
    }
}

/// Shared presentation only; fetching and saving stay in CreateAppDetailsView.
struct ProfileCreationPreview: View {
    let iconData: Data?
    let websiteURL: URL?
    let symbol: String
    let badgeColor: String
    var iconSize: CGFloat = 68
    let websiteName: String
    let profileName: String

    var body: some View {
        VStack(spacing: 10) {
            ProfileBadgedAppIconView(
                data: iconData, websiteURL: websiteURL, symbol: symbol,
                color: badgeColor, size: iconSize, profileName: profileName
            )
            VStack(spacing: 3) {
                Text(websiteName).font(.title3.weight(.semibold))
                Text(profileName).font(.subheadline).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

/// Keeps both sides of the creation toolbar the same size, including while saving.
private struct CreationToolbarButton: View {
    let title: LocalizedStringKey
    var isEnabled = true
    var isPrimary = false
    var isLoading = false
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var buttonWidth = 76.0
    @ScaledMetric(relativeTo: .body) private var buttonHeight = 44.0

    private var showsBlue: Bool { isPrimary && isEnabled }

    var body: some View {
        Button(action: action) {
            surface
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
    }

    private var label: some View {
        ZStack {
            if isLoading { ProgressView() }
            else { Text(title) }
        }
        .font(.body)
        .foregroundStyle(showsBlue ? Color.white : isEnabled ? Color.primary : Color.secondary)
        .frame(width: buttonWidth, height: buttonHeight)
        .contentShape(.capsule)
    }

    @ViewBuilder private var surface: some View {
        if #available(iOS 26.0, *) {
            label.glassEffect(
                showsBlue ? .regular.tint(.blue).interactive() : .regular.interactive(),
                in: .capsule
            )
        } else {
            label.background(showsBlue ? Color.blue : Color(.tertiarySystemFill), in: .capsule)
        }
    }
}
