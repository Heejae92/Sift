import SwiftUI

/// Phase-B placeholder: counter, a flat front card, the three verdict buttons and rewind.
struct ReviewScreen: View {
    @Environment(Catalog.self) private var catalog
    @Environment(ImageLoader.self) private var images
    @Binding var path: [Route]
    @State private var model: ReviewModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                DSColor.canvas
            }
        }
        .task {
            if model == nil { model = ReviewModel(catalog: catalog) }
            model?.sync()
        }
        .onChange(of: catalog.screenshots) { _, _ in model?.catalogDidChange() }
        .onChange(of: catalog.state) { _, _ in model?.catalogDidChange() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DSSpace.s3) {
                    Button { path.append(.trash) } label: { DSIcon.trash.image }
                        .accessibilityLabel("Trash, \(catalog.trashed.count) items")
                    Button { path.append(.library) } label: { DSIcon.library.image }
                        .accessibilityLabel("Library")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(DSColor.canvas.ignoresSafeArea())
    }

    @ViewBuilder
    private func content(_ model: ReviewModel) -> some View {
        VStack(spacing: DSSpace.s4) {
            HStack {
                Text("\(model.position) / \(model.total)").dsType(.counter).foregroundStyle(DSColor.ink)
                    .accessibilityLabel("\(model.position) of \(model.total)")
                Spacer()
            }
            .padding(.horizontal, DSGrid.mobileMargin)

            switch model.phase {
            case .loading:
                Spacer()
            case .noScreenshots:
                placeholderBlock(.allDone, "No screenshots. Honestly, impressive.")
            case .allDone:
                placeholderBlock(.allDone, "Inbox zero, screenshot edition.")
            default:
                if let front = model.deck.first {
                    CardPlaceholder(screenshot: front)
                        .padding(.horizontal, DSGrid.mobileMargin)
                }
            }

            HStack(spacing: DSSpace.s5) {
                Button("Rewind") { Task { await model.rewind(landDuration: DSMotion.dur3) } }
                    .disabled(!model.canRewind)
                ForEach([Verdict.trash, .fave, .archive], id: \.self) { verdict in
                    Button(verdict.caption) { Task { await model.commit(verdict, exitDuration: DSMotion.dur3) } }
                        .disabled(!model.acceptsInput)
                }
            }
            .buttonStyle(.dsPress).dsType(.label).foregroundStyle(DSColor.ink)
            .padding(.bottom, DSSpace.s5)
        }
    }

    private func placeholderBlock(_ block: DSBlock, _ headline: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpace.s4) {
            Text(block.face.text).dsType(.display).foregroundStyle(block.ink).accessibilityHidden(true)
            Text(headline).dsType(.headline).foregroundStyle(block.ink)
        }
        .padding(DSSpace.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(block.fill, in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        .padding(.horizontal, DSGrid.mobileMargin)
    }
}

/// Temporary card: the screenshot fitted on a `surface` rectangle. Replaced by `ScreenshotCard`.
struct CardPlaceholder: View {
    @Environment(ImageLoader.self) private var images
    let screenshot: Screenshot
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous).fill(DSColor.surface)
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
                }
            }
            .task(id: screenshot.id) {
                let scale = UIScreen.main.scale
                image = await images.image(for: screenshot.id, targetSize: CGSize(width: geo.size.width * scale, height: geo.size.height * scale))
            }
        }
        .dsShadow(.floating)
        .accessibilityLabel("Screenshot")
    }
}
