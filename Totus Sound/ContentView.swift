//
//  ContentView.swift
//  Totus Sound
//
//  Created by Julian Muehlschlegel on 8/2/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct TheaterFileCommandActions {
    var newSetup: () -> Void
    var importSetup: () -> Void
    var exportSetup: () -> Void
    var exportCueList: () -> Void
}

extension FocusedValues {
    @Entry var theaterFileCommands: TheaterFileCommandActions?
}

struct ContentView: View {
    @State private var project = TheaterProject.sample
    @State private var selectedTab = WorkspaceTab.layout
    @State private var selectedCueID: Cue.ID?
    @State private var selectedSpeakerID: TheaterSpeaker.ID?
    @State private var cueDraftName = "New Cue"
    @State private var cueDraftColor = CueColor.teal
    @State private var cueDraftIcon = CueIcon.bolt
    @State private var cuesAreVisible = true
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument = TextFileDocument(text: "")
    @State private var exportFilename = "Totus-Theater-Setup.json"
    @State private var statusMessage = "Ready"

    private var selectedCueBinding: Binding<Cue>? {
        guard let index = project.cues.firstIndex(where: { $0.id == selectedCueID }) else { return nil }
        return $project.cues[index]
    }

    private var selectedSpeakerBinding: Binding<TheaterSpeaker>? {
        guard let index = project.setup.speakers.firstIndex(where: { $0.id == selectedSpeakerID }) else { return nil }
        return $project.setup.speakers[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                layoutTab
                    .tabItem { Label("Layout", systemImage: "theatermasks") }
                    .tag(WorkspaceTab.layout)

                speakersTab
                    .tabItem { Label("Speakers", systemImage: "speaker.wave.3") }
                    .tag(WorkspaceTab.speakers)

                cuesTab
                    .tabItem { Label("Cues", systemImage: "list.bullet.rectangle") }
                    .tag(WorkspaceTab.cues)
            }

            statusBar
        }
        .navigationTitle(project.setup.name)
        .focusedSceneValue(\.theaterFileCommands, TheaterFileCommandActions(
            newSetup: newSetup,
            importSetup: { showingImporter = true },
            exportSetup: exportSetup,
            exportCueList: exportCueList
        ))
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            importProject(from: result)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                statusMessage = "Export complete"
            case .failure(let error):
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private var layoutTab: some View {
        HStack(spacing: 0) {
            Form {
                Section("Theater") {
                    TextField("Setup name", text: $project.setup.name)
                }

                Section("Stage") {
                    RectEditor(rect: $project.setup.stageRect)
                }

                Section("Seating") {
                    ForEach($project.setup.seatBlocks) { $seatBlock in
                        RectEditor(rect: $seatBlock)
                    }
                    .onDelete { offsets in
                        project.setup.seatBlocks.remove(atOffsets: offsets)
                    }

                    Button {
                        project.setup.seatBlocks.append(NormalizedRect(x: 0.2, y: 0.34, width: 0.6, height: 0.42))
                    } label: {
                        Label("Add Seat Block", systemImage: "rectangle.stack.badge.plus")
                    }
                }

                Section("Walls") {
                    ForEach($project.setup.walls) { $wall in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wall")
                                .font(.headline)
                            HStack {
                                CoordinateField(label: "Start X", value: $wall.start.x)
                                CoordinateField(label: "Start Y", value: $wall.start.y)
                            }
                            HStack {
                                CoordinateField(label: "End X", value: $wall.end.x)
                                CoordinateField(label: "End Y", value: $wall.end.y)
                            }
                        }
                    }
                    .onDelete { offsets in
                        project.setup.walls.remove(atOffsets: offsets)
                    }

                    Button {
                        project.setup.walls.append(TheaterWall(start: NormalizedPoint(x: 0.1, y: 0.1), end: NormalizedPoint(x: 0.9, y: 0.1)))
                    } label: {
                        Label("Add Wall", systemImage: "plus")
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 380)

            TheaterPlot(
                project: $project,
                mode: .layout,
                selectedCueID: $selectedCueID,
                selectedSpeakerID: $selectedSpeakerID,
                cuesAreVisible: cuesAreVisible,
                onAddCueAtPoint: nil,
                onDeleteCue: deleteCue,
                onToggleCueVisibility: toggleCueVisibility
            )
        }
    }

    private var speakersTab: some View {
        HStack(spacing: 0) {
            Form {
                Section("Speaker Format") {
                    Picker("Format", selection: $project.setup.speakerFormat) {
                        ForEach(SpeakerFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: project.setup.speakerFormat) { _, newValue in
                        applySpeakerFormat(newValue)
                    }
                }

                Section("Speakers") {
                    ForEach($project.setup.speakers) { $speaker in
                        SpeakerRow(speaker: $speaker, isSelected: speaker.id == selectedSpeakerID)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSpeakerID = speaker.id
                            }
                    }
                    .onDelete { offsets in
                        project.setup.speakers.remove(atOffsets: offsets)
                        if let selectedSpeakerID, !project.setup.speakers.contains(where: { $0.id == selectedSpeakerID }) {
                            self.selectedSpeakerID = project.setup.speakers.first?.id
                        }
                    }

                    Button {
                        let speaker = TheaterSpeaker(name: "Speaker \(project.setup.speakers.count + 1)", role: .left, position: NormalizedPoint(x: 0.5, y: 0.2))
                        project.setup.speakers.append(speaker)
                        selectedSpeakerID = speaker.id
                    } label: {
                        Label("Add Speaker", systemImage: "speaker.plus")
                    }
                }

                if let selectedSpeakerBinding {
                    Section("Selected Speaker") {
                        SpeakerInspector(speaker: selectedSpeakerBinding)
                    }
                }
            }
            .frame(minWidth: 280, idealWidth: 340, maxWidth: 380)

            TheaterPlot(
                project: $project,
                mode: .speakers,
                selectedCueID: $selectedCueID,
                selectedSpeakerID: $selectedSpeakerID,
                cuesAreVisible: cuesAreVisible,
                onAddCueAtPoint: nil,
                onDeleteCue: deleteCue,
                onToggleCueVisibility: toggleCueVisibility
            )
        }
    }

    private var cuesTab: some View {
        HStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Button {
                        addCue()
                    } label: {
                        Label("Add Cue", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        cuesAreVisible.toggle()
                    } label: {
                        Label(cuesAreVisible ? "Hide All" : "Show All", systemImage: cuesAreVisible ? "eye.slash" : "eye")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                List(selection: $selectedCueID) {
                    ForEach(project.cues) { cue in
                        CueListRow(cue: cue, isSelected: cue.id == selectedCueID)
                            .tag(cue.id)
                            .contextMenu {
                                Button(cue.isVisible ? "Hide Cue" : "Show Cue") {
                                    toggleCueVisibility(cue.id)
                                }
                                Button("Delete Cue", role: .destructive) {
                                    deleteCue(cue.id)
                                }
                            }
                    }
                    .onDelete { offsets in
                        project.cues.remove(atOffsets: offsets)
                        if let selectedCueID, !project.cues.contains(where: { $0.id == selectedCueID }) {
                            self.selectedCueID = project.cues.first?.id
                        }
                    }
                }
                .frame(minHeight: 180)

                if let selectedCueBinding {
                    CueInspector(cue: selectedCueBinding, setup: project.setup)
                } else {
                    ContentUnavailableView("No Cue Selected", systemImage: "smallcircle.filled.circle", description: Text("Add a cue or select one from the list."))
                        .frame(maxHeight: .infinity)
                }
            }
            .padding()
            .frame(minWidth: 320, idealWidth: 380, maxWidth: 440)

            TheaterPlot(
                project: $project,
                mode: .cues,
                selectedCueID: $selectedCueID,
                selectedSpeakerID: $selectedSpeakerID,
                cuesAreVisible: cuesAreVisible,
                onAddCueAtPoint: { point in
                    addCue(at: point)
                },
                onDeleteCue: deleteCue,
                onToggleCueVisibility: toggleCueVisibility
            )
            .safeAreaInset(edge: .bottom) {
                calculationPanel
            }
        }
    }

    private var calculationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let cue = project.cues.first(where: { $0.id == selectedCueID }) {
                let calculation = MixCalculator.calculate(cue: cue, setup: project.setup)
                HStack {
                    Label(cue.name, systemImage: cue.icon.symbolName)
                        .foregroundStyle(cue.color.swiftUIColor)
                    Spacer()
                    Text("x \(cue.position.x.formatted(.number.precision(.fractionLength(2))))  y \(cue.position.y.formatted(.number.precision(.fractionLength(2))))")
                        .foregroundStyle(.secondary)
                }
                Divider()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    CalculationTile(title: "Pan", value: calculation.panText)
                    CalculationTile(title: "Center Div", value: calculation.centerDivergenceText)
                    CalculationTile(title: "Back L", value: calculation.backLeftText)
                    CalculationTile(title: "Back R", value: calculation.backRightText)
                    CalculationTile(title: "Front Bias", value: calculation.frontBiasText)
                }
            } else {
                Text("Add or select a cue to see panning calculations.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private var statusBar: some View {
        HStack {
            Text(statusMessage)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(project.setup.speakers.count) speakers")
            Text("\(project.cues.count) cues")
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func addCue() {
        addCue(at: NormalizedPoint(x: 0.5, y: 0.5))
    }

    private func addCue(at point: NormalizedPoint) {
        let cue = Cue(name: cueDraftName.isEmpty ? "Untitled Cue" : cueDraftName, position: point, color: cueDraftColor, icon: cueDraftIcon)
        project.cues.append(cue)
        selectedCueID = cue.id
        selectedTab = .cues
        cueDraftName = "New Cue \(project.cues.count + 1)"
        statusMessage = "Added \(cue.name)"
    }

    private func deleteCue(_ id: Cue.ID) {
        project.cues.removeAll { $0.id == id }
        if selectedCueID == id {
            selectedCueID = project.cues.first?.id
        }
        statusMessage = "Deleted cue"
    }

    private func toggleCueVisibility(_ id: Cue.ID) {
        guard let index = project.cues.firstIndex(where: { $0.id == id }) else { return }
        project.cues[index].isVisible.toggle()
        statusMessage = project.cues[index].isVisible ? "Cue shown" : "Cue hidden"
    }

    private func newSetup() {
        project = .blank
        selectedCueID = nil
        selectedSpeakerID = project.setup.speakers.first?.id
        statusMessage = "Started a blank theater setup"
    }

    private func applySpeakerFormat(_ format: SpeakerFormat) {
        let requiredRoles = format.roles
        project.setup.speakers.removeAll { !requiredRoles.contains($0.role) }

        for role in requiredRoles where !project.setup.speakers.contains(where: { $0.role == role }) {
            project.setup.speakers.append(TheaterSpeaker(name: role.rawValue, role: role, position: role.defaultPosition))
        }

        selectedSpeakerID = project.setup.speakers.first?.id
        statusMessage = "Applied \(format.rawValue) speaker layout"
    }

    private func importProject(from result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            if let importedProject = try? decoder.decode(TheaterProject.self, from: data) {
                project = importedProject
                selectedCueID = project.cues.first?.id
            } else {
                project.setup = try decoder.decode(TheaterSetup.self, from: data)
                project.cues = []
                selectedCueID = nil
            }
            selectedSpeakerID = project.setup.speakers.first?.id
            statusMessage = "Imported \(url.lastPathComponent)"
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func exportSetup() {
        do {
            let data = try JSONEncoder.pretty.encode(project.setup)
            exportDocument = TextFileDocument(text: String(decoding: data, as: UTF8.self))
            exportFilename = safeFilename(project.setup.name, fallback: "Totus-Theater-Setup") + "-Setup.json"
            showingExporter = true
        } catch {
            statusMessage = "Could not prepare setup export: \(error.localizedDescription)"
        }
    }

    private func exportCueList() {
        do {
            let rows = project.cues.map { cue in
                CueExportRow(cue: cue, calculation: MixCalculator.calculate(cue: cue, setup: project.setup))
            }
            let data = try JSONEncoder.pretty.encode(rows)
            exportDocument = TextFileDocument(text: String(decoding: data, as: UTF8.self))
            exportFilename = safeFilename(project.setup.name, fallback: "Totus-Cues") + "-Cue-List.json"
            showingExporter = true
        } catch {
            statusMessage = "Could not prepare cue export: \(error.localizedDescription)"
        }
    }

    private func safeFilename(_ value: String, fallback: String) -> String {
        let allowed = value.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "-"
        }
        let filename = String(allowed).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return filename.isEmpty ? fallback : filename
    }
}

private struct TheaterPlot: View {
    @Binding var project: TheaterProject
    let mode: PlotMode
    @Binding var selectedCueID: Cue.ID?
    @Binding var selectedSpeakerID: TheaterSpeaker.ID?
    let cuesAreVisible: Bool
    let onAddCueAtPoint: ((NormalizedPoint) -> Void)?
    let onDeleteCue: (Cue.ID) -> Void
    let onToggleCueVisibility: (Cue.ID) -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Rectangle()
                    .fill(.background)
                grid(in: size)
                staticDrawing(in: size)

                ForEach($project.setup.speakers) { $speaker in
                    DraggableSpeakerMarker(
                        speaker: $speaker,
                        size: size,
                        isSelected: selectedSpeakerID == speaker.id,
                        isEditable: mode == .speakers,
                        onSelect: { selectedSpeakerID = speaker.id }
                    )
                }

                if cuesAreVisible {
                    ForEach($project.cues) { $cue in
                        if cue.isVisible {
                            DraggableCueMarker(
                                cue: $cue,
                                size: size,
                                isSelected: selectedCueID == cue.id,
                                isEditable: mode == .cues,
                                onSelect: { selectedCueID = cue.id },
                                onDelete: { onDeleteCue(cue.id) },
                                onToggleVisibility: { onToggleCueVisibility(cue.id) }
                            )
                        }
                    }
                }

            }
            .overlay(alignment: .topLeading) {
                Text(mode.helperText)
                    .font(.caption)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()
        }
    }

    private func grid(in size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            for index in 0...10 {
                let x = size.width * CGFloat(index) / 10
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))

                let y = size.height * CGFloat(index) / 10
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.secondary.opacity(0.16)), lineWidth: 1)
        }
    }

    private func staticDrawing(in size: CGSize) -> some View {
        Canvas { context, _ in
            let stage = project.setup.stageRect.cgRect(in: size)
            context.fill(Path(stage), with: .color(.indigo.opacity(0.18)))
            context.stroke(Path(stage), with: .color(.indigo), lineWidth: 2)
            context.draw(Text("Stage").font(.caption).foregroundStyle(.indigo), at: CGPoint(x: stage.midX, y: stage.midY))

            for seatBlock in project.setup.seatBlocks {
                let rect = seatBlock.cgRect(in: size)
                context.fill(Path(rect), with: .color(.mint.opacity(0.16)))
                context.stroke(Path(rect), with: .color(.mint), lineWidth: 1.5)
            }

            for wall in project.setup.walls {
                var path = Path()
                path.move(to: wall.start.cgPoint(in: size))
                path.addLine(to: wall.end.cgPoint(in: size))
                context.stroke(path, with: .color(.primary.opacity(0.7)), lineWidth: 4)
            }
        }
    }
}

private struct DraggableCueMarker: View {
    @Binding var cue: Cue
    let size: CGSize
    let isSelected: Bool
    let isEditable: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onToggleVisibility: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Image(systemName: cue.icon.symbolName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: isSelected ? 34 : 28, height: isSelected ? 34 : 28)
                .background(cue.color.swiftUIColor, in: Circle())
                .overlay(Circle().stroke(.white, lineWidth: isSelected ? 4 : 2))
                .shadow(radius: isSelected ? 4 : 1)
        }
        .buttonStyle(.plain)
        .position(cue.position.cgPoint(in: size))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onSelect()
                    guard isEditable else { return }
                    cue.position = NormalizedPoint(location: value.location, in: size)
                }
        )
        .contextMenu {
            Button(cue.isVisible ? "Hide Cue" : "Show Cue") {
                onToggleVisibility()
            }
            Button("Delete Cue", role: .destructive) {
                onDelete()
            }
        }
    }
}

private struct DraggableSpeakerMarker: View {
    @Binding var speaker: TheaterSpeaker
    let size: CGSize
    let isSelected: Bool
    let isEditable: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(speaker.role.shortName)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: isSelected ? 32 : 26, height: isSelected ? 32 : 26)
                .background(.orange, in: Circle())
                .overlay(Circle().stroke(isSelected ? Color.primary : Color.white, lineWidth: isSelected ? 3 : 2))
        }
        .buttonStyle(.plain)
        .position(speaker.position.cgPoint(in: size))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onSelect()
                    guard isEditable else { return }
                    speaker.position = NormalizedPoint(location: value.location, in: size)
                }
        )
    }
}

private struct CueListRow: View {
    let cue: Cue
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: cue.icon.symbolName)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(cue.color.swiftUIColor, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(cue.name)
                    .font(.headline)
                Text("x \(cue.position.x.formatted(.number.precision(.fractionLength(2))))  y \(cue.position.y.formatted(.number.precision(.fractionLength(2))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: cue.isVisible ? "eye" : "eye.slash")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}

private struct CueInspector: View {
    @Binding var cue: Cue
    let setup: TheaterSetup

    var body: some View {
        let calculation = MixCalculator.calculate(cue: cue, setup: setup)

        Form {
            Section("Cue Parameters") {
                TextField("Name", text: $cue.name)
                Picker("Color", selection: $cue.color) {
                    ForEach(CueColor.allCases) { color in
                        Label(color.rawValue, systemImage: "circle.fill")
                            .foregroundStyle(color.swiftUIColor)
                            .tag(color)
                    }
                }
                Picker("Icon", selection: $cue.icon) {
                    ForEach(CueIcon.allCases) { icon in
                        Label(icon.rawValue, systemImage: icon.symbolName).tag(icon)
                    }
                }
                Toggle("Visible", isOn: $cue.isVisible)
            }

            Section("Position") {
                CoordinateField(label: "X", value: $cue.position.x)
                CoordinateField(label: "Y", value: $cue.position.y)
            }

            Section("Calculated Mix") {
                LabeledContent("Pan", value: calculation.panText)
                LabeledContent("Center Divergence", value: calculation.centerDivergenceText)
                LabeledContent("Back Left", value: calculation.backLeftText)
                LabeledContent("Back Right", value: calculation.backRightText)
                LabeledContent("Front Bias", value: calculation.frontBiasText)
            }
        }
    }
}

private struct SpeakerRow: View {
    @Binding var speaker: TheaterSpeaker
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(speaker.role.shortName)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.orange, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(speaker.name)
                    .font(.headline)
                Text(speaker.role.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}

private struct SpeakerInspector: View {
    @Binding var speaker: TheaterSpeaker

    var body: some View {
        TextField("Name", text: $speaker.name)
        Picker("Role", selection: $speaker.role) {
            ForEach(SpeakerRole.allCases) { role in
                Text(role.rawValue).tag(role)
            }
        }
        CoordinateField(label: "X", value: $speaker.position.x)
        CoordinateField(label: "Y", value: $speaker.position.y)
    }
}

private struct RectEditor: View {
    @Binding var rect: NormalizedRect

    var body: some View {
        CoordinateField(label: "X", value: $rect.x)
        CoordinateField(label: "Y", value: $rect.y)
        CoordinateField(label: "Width", value: $rect.width)
        CoordinateField(label: "Height", value: $rect.height)
    }
}

private struct CoordinateField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
            TextField(label, value: $value, format: .number.precision(.fractionLength(2)))
                .textFieldStyle(.roundedBorder)
                .onChange(of: value) { _, newValue in
                    value = min(max(newValue, 0), 1)
                }
        }
    }
}

private struct CalculationTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private enum WorkspaceTab: String, CaseIterable, Identifiable {
    case layout = "Layout"
    case speakers = "Speakers"
    case cues = "Cues"

    var id: String { rawValue }
}

private enum PlotMode {
    case layout
    case speakers
    case cues

    var helperText: String {
        switch self {
        case .layout:
            "Edit stage, seats, and walls in the panel."
        case .speakers:
            "Drag speakers to place them."
        case .cues:
            "Drag cues to reposition them. Use Add Cue to create one."
        }
    }
}

private struct TheaterProject: Codable, Sendable {
    var setup: TheaterSetup
    var cues: [Cue]

    static let blank = TheaterProject(
        setup: TheaterSetup(
            name: "Untitled Theater",
            speakerFormat: .lcr,
            stageRect: NormalizedRect(x: 0.12, y: 0.05, width: 0.76, height: 0.14),
            walls: TheaterProject.defaultWalls,
            seatBlocks: [NormalizedRect(x: 0.18, y: 0.32, width: 0.64, height: 0.48)],
            speakers: TheaterProject.defaultSpeakers
        ),
        cues: []
    )

    static let sample = TheaterProject(
        setup: TheaterSetup(
            name: "Sample LCR Theater",
            speakerFormat: .fivePoint,
            stageRect: NormalizedRect(x: 0.12, y: 0.06, width: 0.76, height: 0.14),
            walls: defaultWalls,
            seatBlocks: [
                NormalizedRect(x: 0.18, y: 0.32, width: 0.28, height: 0.5),
                NormalizedRect(x: 0.54, y: 0.32, width: 0.28, height: 0.5)
            ],
            speakers: defaultSpeakers + [
                TheaterSpeaker(name: "Back Left", role: .backLeft, position: NormalizedPoint(x: 0.15, y: 0.88)),
                TheaterSpeaker(name: "Back Right", role: .backRight, position: NormalizedPoint(x: 0.85, y: 0.88))
            ]
        ),
        cues: [
            Cue(name: "Door Slam", position: NormalizedPoint(x: 0.22, y: 0.78), color: .red, icon: .burst),
            Cue(name: "Phone Ring", position: NormalizedPoint(x: 0.68, y: 0.42), color: .teal, icon: .bell)
        ]
    )

    private static let defaultWalls = [
        TheaterWall(start: NormalizedPoint(x: 0.08, y: 0.04), end: NormalizedPoint(x: 0.92, y: 0.04)),
        TheaterWall(start: NormalizedPoint(x: 0.92, y: 0.04), end: NormalizedPoint(x: 0.92, y: 0.94)),
        TheaterWall(start: NormalizedPoint(x: 0.92, y: 0.94), end: NormalizedPoint(x: 0.08, y: 0.94)),
        TheaterWall(start: NormalizedPoint(x: 0.08, y: 0.94), end: NormalizedPoint(x: 0.08, y: 0.04))
    ]

    private static let defaultSpeakers = [
        TheaterSpeaker(name: "Left", role: .left, position: NormalizedPoint(x: 0.2, y: 0.18)),
        TheaterSpeaker(name: "Center", role: .center, position: NormalizedPoint(x: 0.5, y: 0.16)),
        TheaterSpeaker(name: "Right", role: .right, position: NormalizedPoint(x: 0.8, y: 0.18))
    ]
}

private struct TheaterSetup: Codable, Sendable {
    var name: String
    var speakerFormat: SpeakerFormat
    var stageRect: NormalizedRect
    var walls: [TheaterWall]
    var seatBlocks: [NormalizedRect]
    var speakers: [TheaterSpeaker]
}

private struct TheaterSpeaker: Identifiable, Codable, Sendable {
    var id = UUID()
    var name: String
    var role: SpeakerRole
    var position: NormalizedPoint
}

private struct TheaterWall: Identifiable, Codable, Sendable {
    var id = UUID()
    var start: NormalizedPoint
    var end: NormalizedPoint
}

private struct Cue: Identifiable, Codable, Sendable {
    var id = UUID()
    var name: String
    var position: NormalizedPoint
    var color: CueColor
    var icon: CueIcon
    var isVisible = true

    init(name: String, position: NormalizedPoint, color: CueColor, icon: CueIcon, isVisible: Bool = true) {
        self.name = name
        self.position = position
        self.color = color
        self.icon = icon
        self.isVisible = isVisible
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case position
        case color
        case icon
        case isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        position = try container.decode(NormalizedPoint.self, forKey: .position)
        color = try container.decode(CueColor.self, forKey: .color)
        icon = try container.decode(CueIcon.self, forKey: .icon)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    }
}

private struct CueExportRow: Codable, Sendable {
    let name: String
    let x: Double
    let y: Double
    let icon: CueIcon
    let color: CueColor
    let isVisible: Bool
    let panPercent: Double
    let centerDivergencePercent: Double
    let backLeftPercent: Double
    let backRightPercent: Double
    let frontBiasPercent: Double

    init(cue: Cue, calculation: MixCalculation) {
        name = cue.name
        x = cue.position.x
        y = cue.position.y
        icon = cue.icon
        color = cue.color
        isVisible = cue.isVisible
        panPercent = calculation.panPercent
        centerDivergencePercent = calculation.centerDivergencePercent
        backLeftPercent = calculation.backLeftPercent
        backRightPercent = calculation.backRightPercent
        frontBiasPercent = calculation.frontBiasPercent
    }
}

private struct NormalizedPoint: Codable, Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    init(location: CGPoint, in size: CGSize) {
        self.init(x: location.x / max(size.width, 1), y: location.y / max(size.height, 1))
    }

    func cgPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}

private struct NormalizedRect: Identifiable, Codable, Sendable {
    var id = UUID()
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    func cgRect(in size: CGSize) -> CGRect {
        CGRect(x: x * size.width, y: y * size.height, width: width * size.width, height: height * size.height)
    }
}

private enum SpeakerFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case lr = "LR"
    case lcr = "LCR"
    case fivePoint = "5.x"

    var id: String { rawValue }

    var roles: [SpeakerRole] {
        switch self {
        case .lr:
            [.left, .right]
        case .lcr:
            [.left, .center, .right]
        case .fivePoint:
            [.left, .center, .right, .backLeft, .backRight]
        }
    }
}

private enum SpeakerRole: String, CaseIterable, Identifiable, Codable, Sendable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
    case backLeft = "Back Left"
    case backRight = "Back Right"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .left: "L"
        case .center: "C"
        case .right: "R"
        case .backLeft: "BL"
        case .backRight: "BR"
        }
    }

    var defaultPosition: NormalizedPoint {
        switch self {
        case .left:
            NormalizedPoint(x: 0.2, y: 0.18)
        case .center:
            NormalizedPoint(x: 0.5, y: 0.16)
        case .right:
            NormalizedPoint(x: 0.8, y: 0.18)
        case .backLeft:
            NormalizedPoint(x: 0.15, y: 0.88)
        case .backRight:
            NormalizedPoint(x: 0.85, y: 0.88)
        }
    }
}

private enum CueColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case teal = "Teal"
    case red = "Red"
    case amber = "Amber"
    case blue = "Blue"
    case violet = "Violet"
    case green = "Green"

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .teal: .teal
        case .red: .red
        case .amber: .orange
        case .blue: .blue
        case .violet: .purple
        case .green: .green
        }
    }
}

private enum CueIcon: String, CaseIterable, Identifiable, Codable, Sendable {
    case bolt = "Bolt"
    case bell = "Bell"
    case burst = "Burst"
    case music = "Music"
    case voice = "Voice"
    case ambience = "Ambience"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .bolt: "bolt.fill"
        case .bell: "bell.fill"
        case .burst: "burst.fill"
        case .music: "music.note"
        case .voice: "waveform"
        case .ambience: "wind"
        }
    }
}

private struct MixCalculation: Codable, Sendable {
    let panPercent: Double
    let centerDivergencePercent: Double
    let backLeftPercent: Double
    let backRightPercent: Double
    let frontBiasPercent: Double

    var panText: String {
        if abs(panPercent) < 0.5 {
            return "Center"
        }
        return panPercent < 0 ? "L \(abs(panPercent).roundedPercent)%" : "R \(panPercent.roundedPercent)%"
    }

    var centerDivergenceText: String { "\(centerDivergencePercent.roundedPercent)%" }
    var backLeftText: String { "\(backLeftPercent.roundedPercent)%" }
    var backRightText: String { "\(backRightPercent.roundedPercent)%" }
    var frontBiasText: String { "\(frontBiasPercent.roundedPercent)%" }
}

private enum MixCalculator {
    static func calculate(cue: Cue, setup: TheaterSetup) -> MixCalculation {
        let leftX = setup.speakers.first { $0.role == .left }?.position.x ?? 0.2
        let centerX = setup.speakers.first { $0.role == .center }?.position.x ?? 0.5
        let rightX = setup.speakers.first { $0.role == .right }?.position.x ?? 0.8
        let halfWidth = max(centerX - leftX, rightX - centerX, 0.05)
        let pan = clamp((cue.position.x - centerX) / halfWidth, lower: -1, upper: 1) * 100

        let distanceFromCenter = min(abs(cue.position.x - centerX) / halfWidth, 1)
        let centerDivergence = setup.speakerFormat == .lr ? 0 : (1 - distanceFromCenter) * 100

        let rearAmount = setup.speakerFormat == .fivePoint ? clamp((cue.position.y - 0.45) / 0.45, lower: 0, upper: 1) * 100 : 0
        let rightShare = clamp((cue.position.x - leftX) / max(rightX - leftX, 0.05), lower: 0, upper: 1)
        let backRight = rearAmount * rightShare
        let backLeft = rearAmount * (1 - rightShare)
        let frontBias = max(0, 100 - rearAmount)

        return MixCalculation(
            panPercent: pan,
            centerDivergencePercent: centerDivergence,
            backLeftPercent: backLeft,
            backRightPercent: backRight,
            frontBiasPercent: frontBias
        )
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension Double {
    var roundedPercent: String {
        formatted(.number.precision(.fractionLength(0)))
    }
}

#Preview {
    ContentView()
}
