import AppKit
import SwiftUI

/// The open filter's panel: its settings, Preview, and Cancel / OK.
struct FilterSheet: View {
    @ObservedObject var session: EditorSession
    private var edit: FilterEdit? { session.filterEdit }
    private var settings: FilterSettings { edit?.settings ?? FilterSettings() }
    private func update(_ change: (inout FilterSettings) -> Void) {
        var value = settings
        change(&value)
        session.updateFilter(value, preview: edit?.preview ?? true)
    }

    private var isCameraRaw: Bool { edit?.kind == .cameraRaw }
    /// The widest slider title in the panel, so every slider starts and ends in the same place.
    @State private var labelWidth: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch edit?.kind ?? .gaussianBlur {
            case .curves:
                CurvesControls(settings: Binding(get: { settings.curves }, set: { new in update { $0.curves = new } }))
            case .exposure:
                control("曝光", \.exposure.exposure, range: ExposureSettings.exposureRange, unit: "", decimals: 2, logarithmic: false)
                control("Offset", \.exposure.offset, range: ExposureSettings.offsetRange, unit: "", decimals: 4, logarithmic: false)
                control("伽马", \.exposure.gamma, range: ExposureSettings.gammaRange, unit: "", decimals: 2, logarithmic: true)
            case .gradientMap:
                GradientMapControls(settings: Binding(get: { settings.gradientMap }, set: { new in update { $0.gradientMap = new } }),
                                    pick: { session.openGradientMapColorPicker(highlights: $0) })
            case .blackWhite:
                // Each slider says how bright that family of colors becomes, as Photoshop's do.
                control("红色", \.blackWhite.reds, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(0))
                control("黄色", \.blackWhite.yellows, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(60))
                control("绿色", \.blackWhite.greens, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(120))
                control("青色", \.blackWhite.cyans, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(180))
                control("蓝色", \.blackWhite.blues, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(240))
                control("洋红色", \.blackWhite.magentas, range: BlackWhiteSettings.range, unit: "%", decimals: 0, logarithmic: false, track: .luminance(300))
                Toggle("色调", isOn: flag(\.blackWhite.tint))
                    .help("Color the result while keeping its tones, for a sepia or a cyanotype")
                if settings.blackWhite.tint {
                    control("色相", \.blackWhite.tintHue, range: 0...360, unit: "°", decimals: 0, logarithmic: false, track: .plain)
                    control("饱和度", \.blackWhite.tintSaturation, range: 0...100, unit: "%", decimals: 0, logarithmic: false,
                            track: .saturation(settings.blackWhite.tintHue))
                }
            case .cameraRaw:
                CameraRawControls(session: session)
                    .frame(maxHeight: .infinity, alignment: .top)
            case .colorBalance:
                Text("阴影").font(.headline)
                control("Cyan / Red", \.colorBalance.shadowCyanRed, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.cyanRedTrack)
                control("Magenta / Green", \.colorBalance.shadowMagentaGreen, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.magentaGreenTrack)
                control("Yellow / Blue", \.colorBalance.shadowYellowBlue, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.yellowBlueTrack)
                Text("中间调").font(.headline)
                control("Cyan / Red", \.colorBalance.midCyanRed, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.cyanRedTrack)
                control("Magenta / Green", \.colorBalance.midMagentaGreen, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.magentaGreenTrack)
                control("Yellow / Blue", \.colorBalance.midYellowBlue, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.yellowBlueTrack)
                Text("高光").font(.headline)
                control("Cyan / Red", \.colorBalance.highlightCyanRed, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.cyanRedTrack)
                control("Magenta / Green", \.colorBalance.highlightMagentaGreen, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.magentaGreenTrack)
                control("Yellow / Blue", \.colorBalance.highlightYellowBlue, range: ColorBalanceSettings.range, unit: "", decimals: 0, logarithmic: false, track: Self.yellowBlueTrack)
                Toggle("保持明度", isOn: flag(\.colorBalance.preserveLuminosity))
                    .help("Put each pixel's brightness back afterwards, so only the color moves")
            case .grain:
                control("数量", \.grain.amount, range: GrainSettings.amountRange, unit: "", decimals: 0, logarithmic: false)
                control("大小", \.grain.size, range: GrainSettings.sizeRange, unit: "px", decimals: 1, logarithmic: true)
                control("粗糙度", \.grain.roughness, range: GrainSettings.roughnessRange, unit: "", decimals: 0, logarithmic: false)
            case .removeBackground:
                Text("Hide the background behind a layer mask, keeping the foreground subjects. The pixels stay, so the background can be painted back at any time.")
                    .fixedSize(horizontal: false, vertical: true)
                Picker("质量", selection: Binding(get: { settings.backgroundQuality },
                                                     set: { new in update { $0.backgroundQuality = new } })) {
                    ForEach(BackgroundQuality.allCases, id: \.self) { Text($0.rawValue.chineseUI).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                .help("Basic is quick; Advanced refines the mask against the layer's own detail, for hair and fur")
                if settings.backgroundQuality == .advanced {
                    control("Refine", \.refineEdges, range: 0...40, unit: "px", decimals: 0, logarithmic: false)
                        .help("Pull the mask onto the image's own edges, which recovers hair and fur")
                    control("对比度", \.matteContrast, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                        .help("Clear the haze that leaves background showing through thin areas")
                    control("Shift Edge", \.shiftEdge, range: -10...10, unit: "px", decimals: 0, logarithmic: false)
                        .help("Shrink the mask to drop the rim of background color around the subject, or grow it")
                }
            case .contentAwareFill:
                Text("Fill the selection using surrounding pixels from this layer.")
                    .fixedSize(horizontal: false, vertical: true)
            case .gaussianBlur:
                control("半径", \.radius, range: 0.1...250, unit: "px", decimals: 1, logarithmic: true)
            case .motionBlur:
                control("角度", \.angle, range: -90...90, unit: "°", decimals: 0, logarithmic: false)
                control("距离", \.distance, range: 1...2000, unit: "px", decimals: 0, logarithmic: true)
            case .addNoise:
                control("数量", \.amount, range: 0.1...400, unit: "%", decimals: 1, logarithmic: true)
                HStack(spacing: 10) {
                    Text("分布")
                    Picker("分布", selection: flag(\.gaussian)) {
                        Text("平均分布").tag(false)
                        Text("高斯分布").tag(true)
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }
                Toggle("单色", isOn: flag(\.monochromatic))
            case .dither:
                ditherControls
            case .vignette:
                HStack(spacing: 8) {
                    Text("颜色").frame(width: 95, alignment: .leading)
                    Button { session.openVignetteColorPicker() } label: {
                        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
                        shape.fill(Color(.sRGB, red: settings.vignetteColor.red,
                                         green: settings.vignetteColor.green, blue: settings.vignetteColor.blue))
                            .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1.5) }
                            .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                            .frame(width: 24, height: 24)
                            .contentShape(shape)
                    }
                    .buttonStyle(.plain)
                    .help("Choose the vignette color")
                    Spacer()
                }
                control("数量", \.vignetteAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                    .help("Blend the chosen color into the edges while keeping the center unchanged")
                control("Midpoint", \.vignetteMidpoint, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                control("圆度", \.vignetteRoundness, range: -100...100, unit: "", decimals: 0, logarithmic: false)
                control("羽化", \.vignetteFeather, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                control("高光", \.vignetteHighlights, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                    .help("Protect bright areas near the edge")
            case .bloomGlow:
                control("数量", \.bloomAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                control("半径", \.bloomRadius, range: 1...150, unit: "px", decimals: 0, logarithmic: true)
            case .tonalContrast:
                control("数量", \.tonalAmount, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                control("阴影", \.tonalShadows, range: -100...100, unit: "%", decimals: 0, logarithmic: false)
                control("中间调", \.tonalMidtones, range: -100...100, unit: "%", decimals: 0, logarithmic: false)
                control("高光", \.tonalHighlights, range: -100...100, unit: "%", decimals: 0, logarithmic: false)
                control("半径", \.tonalRadius, range: 1...100, unit: "px", decimals: 0, logarithmic: true)
            case .lensCorrection:
                control("Remove Distortion", \.distortion, range: -100...100, unit: "", decimals: 0, logarithmic: false)
                Text("Positive straightens lines that bow outward (barrel); negative, lines that bow inward (pincushion).")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Toggle("预览", isOn: Binding(get: { edit?.preview ?? true },
                                            set: { session.updateFilter(settings, preview: $0) }))
            if let error = edit?.previewError {
                Text(error).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if session.adjustmentOriginal == nil && session.selection != nil {
                Text("Limited to the selection").font(.callout).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Button("取消") { session.cancelFilter() }.configuredNativeShortcut(.escape)
                Spacer()
                // While the preview is being worked out (Remove Background's mask, Content-Aware Fill) OK waits, so
                // the panel says what it is waiting for rather than showing a disabled button and nothing else.
                // Only the slow filters say so: a quick preview (Dither, a blur) toggling this at every slider step would
                // make the panel flicker as it grows and shrinks.
                if edit?.committing == true || (edit?.preparing == true && edit?.kind.isAutomatic == true) {
                    ProgressView().controlSize(.small)
                    Text(edit?.committing == true ? "正在应用…" : "正在处理…")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Button("确定") { Task { await session.commitFilter() } }
                    .configuredNativeShortcut(.return).buttonStyle(.borderedProminent)
                    .disabled(edit?.kind.isAutomatic == true && (edit?.preparing == true || edit?.previewError != nil))
            }
        }
        .onPreferenceChange(LabelWidthKey.self) { labelWidth = max(60, $0) }
        .padding(24)
        .frame(width: isCameraRaw ? FloatingPanelController.dockedWidth : 380)
        .frame(maxHeight: isCameraRaw ? .infinity : nil, alignment: .top)
        .fixedSize(horizontal: false, vertical: !isCameraRaw)

        .disabled(edit?.committing == true)
        // Filter colors preview live while the app's color picker is open.
        .legacyOnChange(of: session.colorPicker?.color) { _, _ in
            session.previewGradientMapColor()
            session.previewVignetteColor()
            session.previewDitherColor()
        }
    }

    @ViewBuilder private var ditherControls: some View {
        let dither = settings.dither
        Picker("样式", selection: Binding(get: { dither.style }, set: { new in update { $0.dither.style = new } })) {
            ForEach(DitherStyle.groups.indices, id: \.self) { group in
                if group > 0 { Divider() }
                ForEach(DitherStyle.groups[group], id: \.self) { Text($0.rawValue.chineseUI).tag($0) }
            }
        }
        if dither.style.usesPixelSize {
        control("像素大小", \.dither.pixelSize, range: DitherSettings.pixelSizeRange, unit: "px", decimals: 0, logarithmic: false)
            .help("Make each dithered pixel this many pixels across, for a chunky old-screen look")
        }
        if dither.style == .ascii {
            control("字号", \.dither.textSize, range: DitherSettings.textSizeRange, unit: "px", decimals: 0, logarithmic: false)
                .help("The height of each line of characters")
        }
        if dither.style == .scanlines {
            control("行距", \.dither.lineSpacing, range: DitherSettings.lineSpacingRange, unit: "px", decimals: 0, logarithmic: false)
                .help("How far apart the screen's lines are")
            control("Glow", \.dither.glow, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                .help("Light blooming around the lines, like a CRT's phosphors")
            control("点", \.dither.dots, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                .help("Break the lines into glowing beads")
            control("Wobble", \.dither.wobble, range: DitherSettings.wobbleRange, unit: "px", decimals: 0, logarithmic: false)
                .help("Make the lines waver sideways down the screen, like a CRT losing sync")
        }
        if dither.style.isHalftone {
            control("Cell Size", \.dither.cellSize, range: DitherSettings.cellSizeRange, unit: "px", decimals: 0, logarithmic: false)
        }
        if dither.style.isHalftone {
            control("角度", \.dither.angle, range: -90...90, unit: "°", decimals: 0, logarithmic: false)
        }
        if dither.style == .ascii {
            HStack(spacing: 10) {
                Text("Characters")
                TextField("Characters", text: Binding(get: { dither.characters }, set: { new in update { $0.dither.characters = new } }))
                    .textFieldStyle(.roundedBorder).font(.body.monospaced())
            }
            .help("The characters to draw with, in any order: each spot gets the one whose ink best matches its tone")
        }
        if dither.style.hasTones {
            control("Tones", \.dither.levels, range: DitherSettings.levelsRange, unit: "", decimals: 0, logarithmic: false)
                .help("Tones per channel: 2 is pure black and white")
        }
        if dither.style.diffuses {
            control("Diffusion", \.dither.diffusion, range: 0...100, unit: "%", decimals: 0, logarithmic: false)
                .help("How much of each pixel's error spreads to its neighbors. Less gives flatter areas")
        }
        control("浓度", \.dither.density, range: -100...100, unit: "", decimals: 0, logarithmic: false)
            .help("More ink (darker) or less before dithering")
        control("对比度", \.dither.contrast, range: -100...100, unit: "", decimals: 0, logarithmic: false)
        // A menu, like Style: the three choices as segments are wider than the panel, which then flips between
        // squeezing the row and wrapping it, resizing itself at every slider step.
        Picker("颜色", selection: Binding(get: { dither.colors }, set: { new in update { $0.dither.colors = new } })) {
            ForEach(DitherColors.allCases, id: \.self) { Text($0.rawValue.chineseUI).tag($0) }
        }
        .fixedSize()
        if dither.colors == .twoColors {
            HStack(spacing: 8) {
                Text("Dark")
                swatch(dither.dark, help: "Choose the dark color") { session.openDitherColorPicker(light: false) }
                Text("Light").padding(.leading, 10)
                swatch(dither.light, help: "Choose the light color") { session.openDitherColorPicker(light: true) }
                Spacer()
            }
        }
        if dither.pixelSize > 1, dither.style.usesPixelSize {
            Picker("像素形状", selection: Binding(get: { dither.pixelShape }, set: { new in update { $0.dither.pixelShape = new } })) {
                ForEach(DitherPixelShape.allCases, id: \.self) { Text($0.rawValue.chineseUI).tag($0) }
            }
            .fixedSize()
            .help("Draw each chunky pixel as a solid square, or as a round dot like a dot-matrix screen")
        }
        if dither.style.drawsMarks {
            Toggle("Light on Dark", isOn: flag(\.dither.lightOnDark))
                .help("Draw the marks for the light tones on the dark color, like a glowing screen")
        }
    }

    private func swatch(_ color: AdjustmentColor, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            shape.fill(Color(.sRGB, red: color.red, green: color.green, blue: color.blue))
                .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1.5) }
                .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                .frame(width: 24, height: 24)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func flag(_ key: WritableKeyPath<FilterSettings, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } })
    }

    /// The setting put back to its filter's default, as a double-click on a colored slider does.
    static func resetting(_ key: WritableKeyPath<FilterSettings, Double>, in settings: FilterSettings) -> FilterSettings {
        var value = settings
        value[keyPath: key] = FilterSettings()[keyPath: key]
        return value
    }

    static let cyanRedTrack = CameraRawSliderTrack.opposing(NSColor(srgbRed: 0.10, green: 0.72, blue: 0.80, alpha: 1),
                                                            NSColor(srgbRed: 0.86, green: 0.18, blue: 0.20, alpha: 1))
    static let magentaGreenTrack = CameraRawSliderTrack.opposing(NSColor(srgbRed: 0.80, green: 0.22, blue: 0.70, alpha: 1),
                                                                 NSColor(srgbRed: 0.24, green: 0.70, blue: 0.30, alpha: 1))
    static let yellowBlueTrack = CameraRawSliderTrack.opposing(NSColor(srgbRed: 0.95, green: 0.82, blue: 0.18, alpha: 1),
                                                               NSColor(srgbRed: 0.22, green: 0.40, blue: 0.92, alpha: 1))

    /// A slider plus an exact field. Logarithmic sliders give the small values used most most of the travel.
    /// A colored track draws the slider as Camera Raw's, where a double-click on the title or knob resets it.
    private func control(_ title: String, _ key: WritableKeyPath<FilterSettings, Double>, range: ClosedRange<Double>,
                         unit: String, decimals: Int, logarithmic: Bool, track: CameraRawSliderTrack? = nil) -> some View {
        let step = pow(10, Double(decimals))
        let reset = { update { $0 = Self.resetting(key, in: $0) } }
        return HStack(spacing: 10) {
            Text(title).fixedSize()
                .background(GeometryReader { Color.clear.preference(key: LabelWidthKey.self, value: $0.size.width) })
                .frame(width: labelWidth, alignment: .leading)
                .onTapGesture(count: 2) { if track != nil { reset() } }
                .scrubbable(sensitivity: 1 / step,
                            value: Binding(get: { settings[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } }),
                            range: range)
            if let track {
                CameraRawSlider(value: settings[keyPath: key], range: range, track: track,
                                help: "\(title). Double-click to reset.",
                                onChange: { value in update { $0[keyPath: key] = (value * step).rounded() / step } },
                                onReset: reset)
            } else {
                Slider(value: Binding(get: { logarithmic ? log(settings[keyPath: key]) : settings[keyPath: key] },
                                      set: { value in update { $0[keyPath: key] = ((logarithmic ? exp(value) : value) * step).rounded() / step } }),
                       in: logarithmic ? log(range.lowerBound)...log(range.upperBound) : range)
            }
            TextField(title, value: Binding(get: { settings[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } }),
                      format: .number.precision(.fractionLength(0...decimals)))
                .frame(width: 56).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                .unitSuffix(unit)
        }
    }
}

/// Gradient Map's two colors, the gradient they make, and Reverse. The colors are swatches like the
/// tool rail's, and open the app's own color picker.
struct GradientMapControls: View {
    @Binding var settings: GradientMapSettings
    /// Opens the color picker on an end: false for Shadows, true for Highlights.
    let pick: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let ends = settings.ends
            LinearGradient(colors: [color(ends.dark), color(ends.light)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.black.opacity(0.35)) }
                .accessibilityHidden(true)
            HStack(spacing: 20) {
                swatch("阴影", settings.shadows) { pick(false) }
                swatch("高光", settings.highlights) { pick(true) }
                Spacer()
            }
            Toggle("反向", isOn: $settings.reversed)
        }
    }

    private func color(_ value: AdjustmentColor) -> Color { Color(.sRGB, red: value.red, green: value.green, blue: value.blue) }

    private func swatch(_ title: String, _ value: AdjustmentColor, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return HStack(spacing: 8) {
            Button(action: action) {
                shape
                    .fill(color(value))
                    .overlay { shape.inset(by: 1).strokeBorder(.white, lineWidth: 1.5) }
                    .overlay { shape.strokeBorder(.black, lineWidth: 1) }
                    .frame(width: 24, height: 24)
                    .contentShape(shape)
            }
            .buttonStyle(.plain)
            .help("Choose the \(title.lowercased()) color")
            .accessibilityLabel("\(title) color")
            Text(title)
        }
    }
}

private struct LabelWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
