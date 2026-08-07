//
//  ContentView.swift
//  Totus Sound
//
//  Created by Julian Muehlschlegel on 8/2/26.
//

//TODO: Add more colour options
//TODO: Add save state, so you can return to a project.
//TODO: Add more icon options
//TODO: App icon
//TODO: About section
//TODO: Keyboard shortcuts (CMD+Z)

import SwiftUI
import AppKit
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
    @State private var selectedLayoutShapeID: LayoutShape.ID?
    @State private var selectedCueID: Cue.ID?
    @State private var selectedSpeakerID: TheaterSpeaker.ID?
    @State private var cuesAreVisible = true
    @State private var showingImporter = false
    @State private var statusMessage = "Ready"

    private var selectedLayoutShapeBinding: Binding<LayoutShape>? {
        if project.setup.theater.id == selectedLayoutShapeID {
            return $project.setup.theater
        }
        if project.setup.stage.id == selectedLayoutShapeID {
            return $project.setup.stage
        }
        guard let index = project.setup.regions.firstIndex(where: { $0.id == selectedLayoutShapeID }) else { return nil }
        return $project.setup.regions[index]
    }

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
        .onAppear {
            selectedLayoutShapeID = selectedLayoutShapeID ?? project.setup.theater.id
            selectedSpeakerID = selectedSpeakerID ?? project.setup.speakers.first?.id
            selectedCueID = selectedCueID ?? project.cues.first?.id
        }
        .focusedSceneValue(\.theaterFileCommands, TheaterFileCommandActions(
            newSetup: newSetup,
            importSetup: { showingImporter = true },
            exportSetup: exportSetup,
            exportCueList: exportCueList
        ))
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            importProject(from: result)
        }

    }

    private var layoutTab: some View {
        WorkspaceSplit {
            HStack {
                Button {
                    addRegion()
                } label: {
                    Label("Add Region", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    selectedLayoutShapeID = nil
                } label: {
                    Label("Deselect", systemImage: "xmark.circle")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            List {
                Section("Core") {
                    Button {
                        selectedLayoutShapeID = project.setup.theater.id
                    } label: {
                        LayoutShapeRow(shape: project.setup.theater, isSelected: selectedLayoutShapeID == project.setup.theater.id)
                    }
                    .buttonStyle(.glass)

                    Button {
                        selectedLayoutShapeID = project.setup.stage.id
                    } label: {
                        LayoutShapeRow(shape: project.setup.stage, isSelected: selectedLayoutShapeID == project.setup.stage.id)
                    }
                    .buttonStyle(.glass)
                }

                Section("Regions") {
                    ForEach(project.setup.regions) { region in
                        Button {
                            selectedLayoutShapeID = region.id
                        } label: {
                            LayoutShapeRow(shape: region, isSelected: selectedLayoutShapeID == region.id)
                        }
                        .buttonStyle(.glass)
                            .contextMenu {
                                Button(region.isVisible ? "Hide Region" : "Show Region") {
                                    toggleRegionVisibility(region.id)
                                }
                                Button("Delete Region", role: .destructive) {
                                    deleteRegion(region.id)
                                }
                            }
                    }
                    .onDelete { offsets in
                        project.setup.regions.remove(atOffsets: offsets)
                        if let selectedLayoutShapeID, !project.setup.containsShape(id: selectedLayoutShapeID) {
                            self.selectedLayoutShapeID = project.setup.theater.id
                        }
                    }
                }
            }
            //changed from minheight: 260
            .frame(minHeight: 260)

            if let selectedLayoutShapeBinding {
                LayoutShapeInspector(shape: selectedLayoutShapeBinding, canDelete: selectedLayoutShapeBinding.wrappedValue.kind == .region) {
                    deleteRegion(selectedLayoutShapeBinding.wrappedValue.id)
                }
            } else {
                ContentUnavailableView("Nothing Selected", systemImage: "cursorarrow", description: Text("Select the theater, stage, or a region to edit it."))
            }
        } detail: {
            TheaterPlot(
                project: $project,
                mode: .layout,
                selectedLayoutShapeID: $selectedLayoutShapeID,
                selectedCueID: $selectedCueID,
                selectedSpeakerID: $selectedSpeakerID,
                cuesAreVisible: cuesAreVisible,
                onDeleteCue: deleteCue,
                onToggleCueVisibility: toggleCueVisibility
            )
        }
    }

    private var speakersTab: some View {
        WorkspaceSplit {
            Picker("Speaker Format", selection: $project.setup.speakerFormat) {
                ForEach(SpeakerFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: project.setup.speakerFormat) { _, newValue in
                applySpeakerFormat(newValue)
            }

            List {
                ForEach(project.setup.speakers) { speaker in
                    Button {
                        selectedSpeakerID = speaker.id
                    } label: {
                        SpeakerRow(speaker: speaker, isSelected: selectedSpeakerID == speaker.id)
                    }
                    .buttonStyle(.glass)
                        .contextMenu {
                            Button(speaker.isVisible ? "Hide Speaker" : "Show Speaker") {
                                toggleSpeakerVisibility(speaker.id)
                            }
                            Button("Delete Speaker", role: .destructive) {
                                deleteSpeaker(speaker.id)
                            }
                        }
                }
                .onDelete { offsets in
                    project.setup.speakers.remove(atOffsets: offsets)
                    if let selectedSpeakerID, !project.setup.speakers.contains(where: { $0.id == selectedSpeakerID }) {
                        self.selectedSpeakerID = project.setup.speakers.first?.id
                    }
                }

                Button {
                    addSpeaker()
                } label: {
                    Label("Add Speaker", systemImage: "speaker.plus")
                }
            }
            .frame(minHeight: 260)

            if let selectedSpeakerBinding {
                SpeakerInspector(speaker: selectedSpeakerBinding) {
                    deleteSpeaker(selectedSpeakerBinding.wrappedValue.id)
                }
            } else {
                ContentUnavailableView("No Speaker Selected", systemImage: "speaker.slash", description: Text("Add a speaker or select one from the list."))
            }
        } detail: {
            TheaterPlot(
                project: $project,
                mode: .speakers,
                selectedLayoutShapeID: $selectedLayoutShapeID,
                selectedCueID: $selectedCueID,
                selectedSpeakerID: $selectedSpeakerID,
                cuesAreVisible: cuesAreVisible,
                onDeleteCue: deleteCue,
                onToggleCueVisibility: toggleCueVisibility
            )
        }
    }

    private var cuesTab: some View {
        WorkspaceSplit {
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

            List {
                ForEach(project.cues) { cue in
                    Button {
                        selectedCueID = cue.id
                    } label: {
                        CueListRow(cue: cue, isSelected: cue.id == selectedCueID)
                    }
                    .buttonStyle(.glass)
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
            .frame(minHeight: 220)

            if let selectedCueBinding {
                CueInspector(cue: selectedCueBinding, setup: project.setup) {
                    deleteCue(selectedCueBinding.wrappedValue.id)
                }
            } else {
                ContentUnavailableView("No Cue Selected", systemImage: "smallcircle.filled.circle", description: Text("Add a cue or select one from the list."))
            }
        } detail: {
            TheaterPlot(
                project: $project,
                mode: .cues,
                selectedLayoutShapeID: $selectedLayoutShapeID,
                selectedCueID: $selectedCueID,
                selectedSpeakerID: $selectedSpeakerID,
                cuesAreVisible: cuesAreVisible,
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
                    Text("x \(cue.position.x.shortNumber)  y \(cue.position.y.shortNumber)")
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
            Text("\(project.setup.regions.count) regions")
            Text("\(project.cues.count) cues")
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func addRegion() {
        let region = LayoutShape.region(name: "Region \(project.setup.regions.count + 1)", points: [
            NormalizedPoint(x: 0.25, y: 0.38),
            NormalizedPoint(x: 0.55, y: 0.38),
            NormalizedPoint(x: 0.60, y: 0.62),
            NormalizedPoint(x: 0.28, y: 0.68)
        ])
        project.setup.regions.append(region)
        selectedLayoutShapeID = region.id
        statusMessage = "Added region"
    }

    private func deleteRegion(_ id: LayoutShape.ID) {
        project.setup.regions.removeAll { $0.id == id }
        if selectedLayoutShapeID == id {
            selectedLayoutShapeID = project.setup.theater.id
        }
        statusMessage = "Deleted region"
    }

    private func toggleRegionVisibility(_ id: LayoutShape.ID) {
        guard let index = project.setup.regions.firstIndex(where: { $0.id == id }) else { return }
        project.setup.regions[index].isVisible.toggle()
    }

    private func addSpeaker() {
        let speaker = TheaterSpeaker(name: "Speaker \(project.setup.speakers.count + 1)", role: .left, position: NormalizedPoint(x: 0.5, y: 0.2))
        project.setup.speakers.append(speaker)
        selectedSpeakerID = speaker.id
        statusMessage = "Added speaker"
    }

    private func deleteSpeaker(_ id: TheaterSpeaker.ID) {
        project.setup.speakers.removeAll { $0.id == id }
        if selectedSpeakerID == id {
            selectedSpeakerID = project.setup.speakers.first?.id
        }
        statusMessage = "Deleted speaker"
    }

    private func toggleSpeakerVisibility(_ id: TheaterSpeaker.ID) {
        guard let index = project.setup.speakers.firstIndex(where: { $0.id == id }) else { return }
        project.setup.speakers[index].isVisible.toggle()
    }

    private func addCue() {
        let cue = Cue(name: "Cue \(project.cues.count + 1)", position: NormalizedPoint(x: 0.5, y: 0.5), color: .teal, icon: .bolt)
        project.cues.append(cue)
        selectedCueID = cue.id
        selectedTab = .cues
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
    }

    private func newSetup() {
        project = .blank
        selectedLayoutShapeID = project.setup.theater.id
        selectedSpeakerID = project.setup.speakers.first?.id
        selectedCueID = nil
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
            selectedLayoutShapeID = project.setup.theater.id
            selectedSpeakerID = project.setup.speakers.first?.id
            statusMessage = "Imported \(url.lastPathComponent)"
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func exportSetup() {
        do {
            let data = try JSONEncoder.pretty.encode(project.setup)
            let filename = safeFilename(project.setup.name, fallback: "Totus-Theater-Setup") + "-Setup.json"
            
            let panel = NSSavePanel()
            panel.nameFieldStringValue = filename
            panel.allowedContentTypes = [.json]
            
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    do {
                        try data.write(to: url)
                        Task { @MainActor in
                            self.statusMessage = "Export successful!"
                        }
                    } catch {
                        Task { @MainActor in
                            self.statusMessage = "Failed to save file: \(error.localizedDescription)"
                        }
                    }
                }
            }
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
            let filename = safeFilename(project.setup.name, fallback: "Totus-Cues") + "-Cue-List.json"
            
            let panel = NSSavePanel()
            panel.nameFieldStringValue = filename
            panel.allowedContentTypes = [.json]
            
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    do {
                        try data.write(to: url)
                        
                        Task { @MainActor in
                            self.statusMessage = "Export successful!"
                        }
                    } catch {
                        Task { @MainActor in
                            self.statusMessage = "Failed to save file: \(error.localizedDescription)"
                        }
                    }
                }
            }
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

private struct WorkspaceSplit<Sidebar: View, Detail: View>: View {
    @ViewBuilder var sidebar: Sidebar
    @ViewBuilder var detail: Detail

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 12) {
                sidebar
            }
            .padding()
            .frame(minWidth: 330, idealWidth: 390, maxWidth: 450)

            detail
        }
    }
}

private struct TheaterPlot: View {
    @Binding var project: TheaterProject
    let mode: PlotMode
    @Binding var selectedLayoutShapeID: LayoutShape.ID?
    @Binding var selectedCueID: Cue.ID?
    @Binding var selectedSpeakerID: TheaterSpeaker.ID?
    let cuesAreVisible: Bool
    let onDeleteCue: (Cue.ID) -> Void
    let onToggleCueVisibility: (Cue.ID) -> Void
    @State private var viewport = PlotViewport()

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Rectangle()
                    .fill(.background)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedLayoutShapeID = nil
                        selectedCueID = nil
                        selectedSpeakerID = nil
                    }

                grid(in: size, viewport: viewport)
            
                ShapeOverlay(
                    shape: $project.setup.theater,
                    size: size,
                    viewport: viewport,
                    isSelected: selectedLayoutShapeID == project.setup.theater.id,
                    isEditable: mode == .layout,
                    isDimmed: false,
                    onSelect: { selectedLayoutShapeID = project.setup.theater.id }
                )

                if project.setup.stage.isVisible {
                    ShapeOverlay(
                        shape: $project.setup.stage,
                        size: size,
                        viewport: viewport,
                        isSelected: selectedLayoutShapeID == project.setup.stage.id,
                        isEditable: mode == .layout,
                        isDimmed: false,
                        onSelect: { selectedLayoutShapeID = project.setup.stage.id }
                    )
                }

                ForEach($project.setup.regions) { $region in
                    if region.isVisible {
                        ShapeOverlay(
                            shape: $region,
                            size: size,
                            viewport: viewport,
                            isSelected: selectedLayoutShapeID == region.id,
                            isEditable: mode == .layout,
                            isDimmed: mode == .cues,
                            onSelect: { selectedLayoutShapeID = region.id }
                        )
                        .zIndex(selectedLayoutShapeID == region.id ? 1 : 0)
                    }
                }

                if mode.showsSpeakers {
                    ForEach($project.setup.speakers) { $speaker in
                        if speaker.isVisible {
                            DraggableSpeakerMarker(
                                speaker: $speaker,
                                size: size,
                                viewport: viewport,
                                isSelected: selectedSpeakerID == speaker.id,
                                isEditable: mode == .speakers,
                                isDimmed: mode == .cues,
                                onSelect: { selectedSpeakerID = speaker.id }
                            )
                        }
                    }
                }

                if mode.showsCues && cuesAreVisible {
                    ForEach($project.cues) { $cue in
                        if cue.isVisible {
                            DraggableCueMarker(
                                cue: $cue,
                                size: size,
                                viewport: viewport,
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
            .coordinateSpace(name: "plot")
            .overlay(alignment: .topLeading) {
                Text(mode.helperText)
                    .font(.caption)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                PlotViewportControls(viewport: $viewport)
                    .padding(12)
            }
            .background(
                TrackpadViewportReader(
                    onScroll: { delta in
                        viewport.pan.width += delta.width
                        viewport.pan.height += delta.height
                    },
                    onMagnify: { magnification, location in
                        viewport.zoom(by: magnification, around: location, in: size)
                    }
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()
        }
    }

    private func grid(in size: CGSize, viewport: PlotViewport) -> some View {
        Canvas { context, _ in
            var path = Path()
            let spacing: CGFloat = 0.1
            let worldScale = viewport.worldScale
            let minX = floor((0 - viewport.pan.width) / max(worldScale * viewport.zoom, 1) / spacing) * spacing
            let maxX = ceil((size.width - viewport.pan.width) / max(worldScale * viewport.zoom, 1) / spacing) * spacing
            let minY = floor((0 - viewport.pan.height) / max(worldScale * viewport.zoom, 1) / spacing) * spacing
            let maxY = ceil((size.height - viewport.pan.height) / max(worldScale * viewport.zoom, 1) / spacing) * spacing

            var xValue = minX
            while xValue <= maxX {
                let x = xValue * worldScale * viewport.zoom + viewport.pan.width
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                xValue += spacing
            }

            var yValue = minY
            while yValue <= maxY {
                let y = yValue * worldScale * viewport.zoom + viewport.pan.height
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                yValue += spacing
            }
            context.stroke(path, with: .color(.secondary.opacity(0.16)), lineWidth: 1)
        }
    }
}

private struct PlotViewportControls: View {
    @Binding var viewport: PlotViewport

    var body: some View {
        HStack(spacing: 6) {
            Button {
                viewport.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            Button {
                viewport.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            Button {
                viewport.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
        }
        .buttonStyle(.glass)
        .padding(8)
//        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TrackpadViewportReader: NSViewRepresentable {
    let onScroll: (CGSize) -> Void
    let onMagnify: (CGFloat, CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScroll: onScroll, onMagnify: onMagnify)
    }

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        context.coordinator.view = view
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        context.coordinator.onScroll = onScroll
        context.coordinator.onMagnify = onMagnify
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: TrackingView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class TrackingView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }

    final class Coordinator {
        var onScroll: (CGSize) -> Void
        var onMagnify: (CGFloat, CGPoint) -> Void
        weak var view: TrackingView?
        private var monitor: Any?

        init(onScroll: @escaping (CGSize) -> Void, onMagnify: @escaping (CGFloat, CGPoint) -> Void) {
            self.onScroll = onScroll
            self.onMagnify = onMagnify
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                guard let self, let view, let window = view.window, event.window === window else {
                    return event
                }

                let locationInWindow = event.locationInWindow
                let locationInView = view.convert(locationInWindow, from: nil)
                guard view.bounds.contains(locationInView) else {
                    return event
                }

                switch event.type {
                case .scrollWheel:
                    onScroll(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
                case .magnify:
                    onMagnify(event.magnification, locationInView)
                default:
                    break
                }

                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        deinit {
            removeMonitor()
        }
    }
}

private struct PlotViewport: Equatable {
    let worldScale: CGFloat = 720
    var zoom: CGFloat = 1
    var pan: CGSize = .zero

    mutating func zoomIn() {
        zoom = Self.clampedZoom(zoom * 1.25)
    }

    mutating func zoomOut() {
        zoom = Self.clampedZoom(zoom / 1.25)
    }

    mutating func reset() {
        zoom = 1
        pan = .zero
    }

    mutating func zoom(by magnification: CGFloat, around location: CGPoint, in size: CGSize) {
        let before = normalizedPoint(for: location, in: size)
        zoom = Self.clampedZoom(zoom * (1 + magnification))
        let after = screenPoint(for: before, in: size)
        pan.width += location.x - after.x
        pan.height += location.y - after.y
    }

    static func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.35), 5)
    }

    func screenPoint(for point: NormalizedPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * worldScale * zoom + pan.width,
            y: point.y * worldScale * zoom + pan.height
        )
    }

    func normalizedPoint(for location: CGPoint, in size: CGSize) -> NormalizedPoint {
        NormalizedPoint(
            x: (location.x - pan.width) / max(worldScale * zoom, 1),
            y: (location.y - pan.height) / max(worldScale * zoom, 1)
        )
    }

    func normalizedTranslation(for translation: CGSize, in size: CGSize) -> CGSize {
        CGSize(
            width: translation.width / max(worldScale * zoom, 1),
            height: translation.height / max(worldScale * zoom, 1)
        )
    }
}

private struct PolygonHitShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }
}

private struct ShapeOverlay: View {
    private let vertexHandleSize: CGFloat = 14
    private let vertexDragTargetSize: CGFloat = 50

    @Binding var shape: LayoutShape
    let size: CGSize
    let viewport: PlotViewport
    let isSelected: Bool
    let isEditable: Bool
    let isDimmed: Bool
    let onSelect: () -> Void
    
    @State private var shapeDragStartPoints: [NormalizedPoint]?
    @State private var vertexDragStartPoint: NormalizedPoint?

    var body: some View {
        ZStack {
            ZStack {
                shapePath
                    .fill(shape.color.swiftUIColor.opacity(shape.kind == .theater ? 0.05 : 0.18))
                shapePath
                    .stroke(isSelected ? Color.accentColor : shape.color.swiftUIColor.opacity(0.9), lineWidth: isSelected ? 3 : 1.5)
            }
            .contentShape(PolygonHitShape(points: shape.displayPoints(in: size, viewport: viewport)))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("plot"))
                    .onChanged { value in
                        onSelect()
                        guard isEditable else { return }
                        guard vertexDragStartPoint == nil else { return }
                        
                        let start = shapeDragStartPoints ?? shape.points
                        shapeDragStartPoints = start
                        let translation = viewport.normalizedTranslation(for: value.translation, in: size)
                        shape.points = start.map { $0.translated(by: translation) }
                    }
                    .onEnded { _ in
                        shapeDragStartPoints = nil
                    }
            )

            if isSelected && isEditable {
                ForEach(shape.points.indices, id: \.self) { index in
                    VertexHandle(visibleSize: vertexHandleSize, targetSize: vertexDragTargetSize)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("plot"))
                                .onChanged { value in
                                    onSelect()
                                    let start = vertexDragStartPoint ?? shape.points[index]
                                    vertexDragStartPoint = start
                                    shape.points[index] = start.translated(by: viewport.normalizedTranslation(for: value.translation, in: size))
                                }
                                .onEnded { _ in
                                    vertexDragStartPoint = nil
                                }
                        )
                        .position(viewport.screenPoint(for: shape.points[index], in: size))
                        .zIndex(10)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .opacity(isDimmed ? 0.45 : 1)
        .allowsHitTesting(isEditable)
    }

    private var shapePath: Path {
        Path { path in
            let points = shape.displayPoints(in: size, viewport: viewport)
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }
}

private struct VertexHandle: View {
    let visibleSize: CGFloat
    let targetSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.001))
                .frame(width: targetSize, height: targetSize)

                Circle()
                    .fill(.background)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                    .frame(width: visibleSize, height: visibleSize)
        }
        .frame(width: targetSize, height: targetSize, alignment: .center)
        .contentShape(Circle())
    }
}

private struct DraggableCueMarker: View {
    @Binding var cue: Cue
    let size: CGSize
    let viewport: PlotViewport
    let isSelected: Bool
    let isEditable: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onToggleVisibility: () -> Void
    @State private var dragStartPosition: NormalizedPoint?

    var body: some View {
        Image(systemName: cue.icon.symbolName)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: isSelected ? 34 : 28, height: isSelected ? 34 : 28)
            .background(cue.color.swiftUIColor, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: isSelected ? 4 : 2))
            .shadow(radius: isSelected ? 4 : 1)
            .position(viewport.screenPoint(for: cue.position, in: size))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("plot"))
                    .onChanged { value in
                        onSelect()
                        guard isEditable else { return }
                        let start = dragStartPosition ?? cue.position
                        dragStartPosition = start
                        cue.position = start.translated(by: viewport.normalizedTranslation(for: value.translation, in: size))
                    }
                    .onEnded { _ in
                        dragStartPosition = nil
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
    let viewport: PlotViewport
    let isSelected: Bool
    let isEditable: Bool
    let isDimmed: Bool
    let onSelect: () -> Void
    @State private var dragStartPosition: NormalizedPoint?

    var body: some View {
        Text(speaker.role.shortName)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .frame(width: isSelected ? 32 : 26, height: isSelected ? 32 : 26)
            .background(.orange, in: Circle())
            .overlay(Circle().stroke(isSelected ? Color.primary : Color.white, lineWidth: isSelected ? 3 : 2))
            .opacity(isDimmed ? 0.45 : 1)
            .allowsHitTesting(isEditable)
            .position(viewport.screenPoint(for: speaker.position, in: size))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("plot"))
                    .onChanged { value in
                        onSelect()
                        guard isEditable else { return }
                        let start = dragStartPosition ?? speaker.position
                        dragStartPosition = start
                        speaker.position = start.translated(by: viewport.normalizedTranslation(for: value.translation, in: size))
                    }
                    .onEnded { _ in
                        dragStartPosition = nil
                    }
            )
    }
}

private struct LayoutShapeRow: View {
    let shape: LayoutShape
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: shape.kind.symbolName)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(shape.color.swiftUIColor, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(shape.name)
                    .font(.headline)
                Text("\(shape.points.count) points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: shape.isVisible ? "eye" : "eye.slash")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
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
                Text("x \(cue.position.x.shortNumber)  y \(cue.position.y.shortNumber)")
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

private struct SpeakerRow: View {
    let speaker: TheaterSpeaker
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
            Image(systemName: speaker.isVisible ? "eye" : "eye.slash")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}

private struct LayoutShapeInspector: View {
    @Binding var shape: LayoutShape
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Shape")
                .font(.headline)
            TextField("Name", text: $shape.name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Circle()
                    .fill(shape.color.swiftUIColor)
                    .frame(width: 18, height: 18)
                Picker("Color", selection: $shape.color) {
                    ForEach(CueColor.allCases) { color in
                        Label {
                            Text(color.rawValue)
                        } icon: {
                            Circle().fill(color.swiftUIColor).frame(width: 12, height: 12)
                        }
                        .tag(color)
                    }
                }
            }
            Toggle("Visible", isOn: $shape.isVisible)
                .toggleStyle(.switch)
                .disabled(shape.kind == .theater)

            HStack {
                Button("Add Point") {
                    shape.addPoint()
                }
                Button("Remove Point") {
                    shape.removeLastPoint()
                }
                .disabled(shape.points.count <= 3)
            }

            HStack {
                Button("Rotate Left") {
                    shape.rotate(byDegrees: -15)
                }
                Button("Rotate Right") {
                    shape.rotate(byDegrees: 15)
                }
            }

            if canDelete {
                Button("Delete Region", role: .destructive, action: onDelete)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CueInspector: View {
    @Binding var cue: Cue
    let setup: TheaterSetup
    let onDelete: () -> Void

    var body: some View {
//        let calculation = MixCalculator.calculate(cue: cue, setup: setup)

        VStack(alignment: .leading, spacing: 12) {
            Text("Cue Parameters")
                .font(.headline)
            TextField("Name", text: $cue.name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Circle()
                    .fill(cue.color.swiftUIColor)
                    .frame(width: 18, height: 18)
                Picker("Color", selection: $cue.color) {
                    ForEach(CueColor.allCases) { color in
                        Label {
                            Text(color.rawValue)
                        } icon: {
                            Circle().fill(color.swiftUIColor).frame(width: 12, height: 12)
                        }
                        .tag(color)
                    }
                }
            }
            Picker("Icon", selection: $cue.icon) {
                ForEach(CueIcon.allCases) { icon in
                    Label(icon.rawValue, systemImage: icon.symbolName).tag(icon)
                }
            }
            Toggle("Visible", isOn: $cue.isVisible)
                .toggleStyle(.switch)
            CoordinateField(label: "X", value: $cue.position.x)
            CoordinateField(label: "Y", value: $cue.position.y)

//            Divider()
//            LabeledContent("Pan", value: calculation.panText)
//            LabeledContent("Center Divergence", value: calculation.centerDivergenceText)
//            LabeledContent("Back Left", value: calculation.backLeftText)
//            LabeledContent("Back Right", value: calculation.backRightText)
//            LabeledContent("Front Bias", value: calculation.frontBiasText)

            Button("Delete Cue", role: .destructive, action: onDelete)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SpeakerInspector: View {
    @Binding var speaker: TheaterSpeaker
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Speaker")
                .font(.headline)
            TextField("Name", text: $speaker.name)
                .textFieldStyle(.roundedBorder)
            Picker("Role", selection: $speaker.role) {
                ForEach(SpeakerRole.allCases) { role in
                    Text(role.rawValue).tag(role)
                }
            }
            Toggle("Visible", isOn: $speaker.isVisible)
                .toggleStyle(.switch)
            CoordinateField(label: "X", value: $speaker.position.x)
            CoordinateField(label: "Y", value: $speaker.position.y)
            Button("Delete Speaker", role: .destructive, action: onDelete)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CoordinateField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 70, alignment: .leading)
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

    var showsSpeakers: Bool {
        self == .speakers || self == .cues
    }

    var showsCues: Bool {
        self == .cues
    }

    var helperText: String {
        switch self {
        case .layout:
            "Drag shapes, vertices, or use Rotate in the inspector."
        case .speakers:
            "Drag speakers to place them."
        case .cues:
            "Drag cues to reposition them. Speakers are dim reference markers."
        }
    }
}

private struct TheaterProject: Codable, Sendable {
    var setup: TheaterSetup
    var cues: [Cue]

    static let blank = TheaterProject(setup: .blank, cues: [])
    static let sample = TheaterProject(setup: .sample, cues: [
        Cue(name: "Door Slam", position: NormalizedPoint(x: 0.22, y: 0.78), color: .red, icon: .burst),
        Cue(name: "Phone Ring", position: NormalizedPoint(x: 0.68, y: 0.42), color: .teal, icon: .bell)
    ])
}

private struct TheaterSetup: Codable, Sendable {
    var name: String
    var speakerFormat: SpeakerFormat
    var theater: LayoutShape
    var stage: LayoutShape
    var regions: [LayoutShape]
    var speakers: [TheaterSpeaker]

    static let blank = TheaterSetup(
        name: "Untitled Theater",
        speakerFormat: .lcr,
        theater: .theater(points: LayoutShape.defaultTheaterPoints),
        stage: .stage(points: LayoutShape.rectPoints(x: 0.12, y: 0.06, width: 0.76, height: 0.14)),
        regions: [LayoutShape.region(name: "Seating", points: LayoutShape.rectPoints(x: 0.18, y: 0.32, width: 0.64, height: 0.5))],
        speakers: SpeakerRole.lcrRoles.map { TheaterSpeaker(name: $0.rawValue, role: $0, position: $0.defaultPosition) }
    )

    static let sample = TheaterSetup(
        name: "Sample LCR Theater",
        speakerFormat: .fivePoint,
        theater: .theater(points: LayoutShape.defaultTheaterPoints),
        stage: .stage(points: LayoutShape.rectPoints(x: 0.12, y: 0.06, width: 0.76, height: 0.14)),
        regions: [
            LayoutShape.region(name: "House Left", points: LayoutShape.rectPoints(x: 0.18, y: 0.32, width: 0.28, height: 0.5)),
            LayoutShape.region(name: "House Right", points: LayoutShape.rectPoints(x: 0.54, y: 0.32, width: 0.28, height: 0.5))
        ],
        speakers: SpeakerRole.fivePointRoles.map { TheaterSpeaker(name: $0.rawValue, role: $0, position: $0.defaultPosition) }
    )

    func containsShape(id: LayoutShape.ID) -> Bool {
        theater.id == id || stage.id == id || regions.contains { $0.id == id }
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case speakerFormat
        case theater
        case stage
        case regions
        case speakers
        case stageRect
        case seatBlocks
    }

    init(name: String, speakerFormat: SpeakerFormat, theater: LayoutShape, stage: LayoutShape, regions: [LayoutShape], speakers: [TheaterSpeaker]) {
        self.name = name
        self.speakerFormat = speakerFormat
        self.theater = theater
        self.stage = stage
        self.regions = regions
        self.speakers = speakers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(speakerFormat, forKey: .speakerFormat)
        try container.encode(theater, forKey: .theater)
        try container.encode(stage, forKey: .stage)
        try container.encode(regions, forKey: .regions)
        try container.encode(speakers, forKey: .speakers)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        speakerFormat = try container.decodeIfPresent(SpeakerFormat.self, forKey: .speakerFormat) ?? .lcr
        speakers = try container.decodeIfPresent([TheaterSpeaker].self, forKey: .speakers) ?? SpeakerRole.lcrRoles.map { TheaterSpeaker(name: $0.rawValue, role: $0, position: $0.defaultPosition) }

        if let theater = try container.decodeIfPresent(LayoutShape.self, forKey: .theater),
           let stage = try container.decodeIfPresent(LayoutShape.self, forKey: .stage) {
            self.theater = theater
            self.stage = stage
            regions = try container.decodeIfPresent([LayoutShape].self, forKey: .regions) ?? []
        } else {
            theater = .theater(points: LayoutShape.defaultTheaterPoints)
            let oldStage = try container.decodeIfPresent(LegacyRect.self, forKey: .stageRect)
            stage = .stage(points: oldStage?.points ?? LayoutShape.rectPoints(x: 0.12, y: 0.06, width: 0.76, height: 0.14))
            let oldSeatBlocks = try container.decodeIfPresent([LegacyRect].self, forKey: .seatBlocks) ?? []
            regions = oldSeatBlocks.enumerated().map { index, rect in
                LayoutShape.region(name: "Region \(index + 1)", points: rect.points)
            }
        }
    }
}

private struct LayoutShape: Identifiable, Codable, Sendable {
    var id = UUID()
    var name: String
    var kind: LayoutShapeKind
    var points: [NormalizedPoint]
    var color: CueColor
    var isVisible = true

    static let defaultTheaterPoints = [
        NormalizedPoint(x: 0.08, y: 0.04),
        NormalizedPoint(x: 0.92, y: 0.04),
        NormalizedPoint(x: 0.92, y: 0.94),
        NormalizedPoint(x: 0.08, y: 0.94)
    ]

    static func theater(points: [NormalizedPoint]) -> LayoutShape {
        LayoutShape(name: "Theater Boundary", kind: .theater, points: points, color: .blue, isVisible: true)
    }

    static func stage(points: [NormalizedPoint]) -> LayoutShape {
        LayoutShape(name: "Stage", kind: .stage, points: points, color: .violet, isVisible: true)
    }

    static func region(name: String, points: [NormalizedPoint]) -> LayoutShape {
        LayoutShape(name: name, kind: .region, points: points, color: .green, isVisible: true)
    }

    static func rectPoints(x: Double, y: Double, width: Double, height: Double) -> [NormalizedPoint] {
        [
            NormalizedPoint(x: x, y: y),
            NormalizedPoint(x: x + width, y: y),
            NormalizedPoint(x: x + width, y: y + height),
            NormalizedPoint(x: x, y: y + height)
        ]
    }

    var center: NormalizedPoint {
        guard !points.isEmpty else { return NormalizedPoint(x: 0.5, y: 0.5) }
        let x = points.map(\.x).reduce(0, +) / Double(points.count)
        let y = points.map(\.y).reduce(0, +) / Double(points.count)
        return NormalizedPoint(x: x, y: y)
    }

    func displayPoints(in size: CGSize, viewport: PlotViewport) -> [CGPoint] {
        points.map { viewport.screenPoint(for: $0, in: size) }
    }

    mutating func moveCenter(to newCenter: NormalizedPoint) {
        let oldCenter = center
        let dx = newCenter.x - oldCenter.x
        let dy = newCenter.y - oldCenter.y
        points = points.map { NormalizedPoint(x: $0.x + dx, y: $0.y + dy) }
    }

    mutating func addPoint() {
        guard points.count >= 2 else {
            points.append(NormalizedPoint(x: 0.5, y: 0.5))
            return
        }
        let first = points[0]
        let last = points[points.count - 1]
        points.append(NormalizedPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2))
    }

    mutating func removeLastPoint() {
        guard points.count > 3 else { return }
        points.removeLast()
    }

    mutating func rotate(byDegrees degrees: Double) {
        let radians = degrees * .pi / 180
        let c = center
        points = points.map { point in
            let x = point.x - c.x
            let y = point.y - c.y
            return NormalizedPoint(
                x: c.x + x * cos(radians) - y * sin(radians),
                y: c.y + x * sin(radians) + y * cos(radians)
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case points
        case color
        case isVisible
    }

    init(id: UUID = UUID(), name: String, kind: LayoutShapeKind, points: [NormalizedPoint], color: CueColor, isVisible: Bool = true) {
        self.id = id
        self.name = name
        self.kind = kind
        self.points = points
        self.color = color
        self.isVisible = isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(LayoutShapeKind.self, forKey: .kind)
        points = try container.decode([NormalizedPoint].self, forKey: .points)
        color = try container.decodeIfPresent(CueColor.self, forKey: .color) ?? .green
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    }
}

private enum LayoutShapeKind: String, Codable, Sendable {
    case theater
    case stage
    case region

    var symbolName: String {
        switch self {
        case .theater: "pentagon"
        case .stage: "theatermasks"
        case .region: "rectangle.dashed"
        }
    }
}

private struct TheaterSpeaker: Identifiable, Codable, Sendable {
    var id = UUID()
    var name: String
    var role: SpeakerRole
    var position: NormalizedPoint
    var isVisible = true

    init(id: UUID = UUID(), name: String, role: SpeakerRole, position: NormalizedPoint, isVisible: Bool = true) {
        self.id = id
        self.name = name
        self.role = role
        self.position = position
        self.isVisible = isVisible
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case position
        case isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(SpeakerRole.self, forKey: .role)
        position = try container.decode(NormalizedPoint.self, forKey: .position)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    }
}

private struct Cue: Identifiable, Codable, Sendable {
    var id = UUID()
    var name: String
    var position: NormalizedPoint
    var color: CueColor
    var icon: CueIcon
    var isVisible = true

    init(id: UUID = UUID(), name: String, position: NormalizedPoint, color: CueColor, icon: CueIcon, isVisible: Bool = true) {
        self.id = id
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
        self.x = x
        self.y = y
    }

    init(location: CGPoint, in size: CGSize) {
        self.init(x: location.x / max(size.width, 1), y: location.y / max(size.height, 1))
    }

    func cgPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    func translated(by translation: CGSize) -> NormalizedPoint {
        NormalizedPoint(x: x + translation.width, y: y + translation.height)
    }
}

private struct LegacyRect: Codable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var points: [NormalizedPoint] {
        LayoutShape.rectPoints(x: x, y: y, width: width, height: height)
    }
}

private enum SpeakerFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case lr = "LR"
    case lcr = "LCR"
    case fivePoint = "5.x"

    var id: String { rawValue }

    var roles: [SpeakerRole] {
        switch self {
        case .lr: SpeakerRole.lrRoles
        case .lcr: SpeakerRole.lcrRoles
        case .fivePoint: SpeakerRole.fivePointRoles
        }
    }
}

private enum SpeakerRole: String, CaseIterable, Identifiable, Codable, Sendable {
    case left = "Left"
    case center = "Center"
    case right = "Right"
    case backLeft = "Back Left"
    case backRight = "Back Right"

    static let lrRoles: [SpeakerRole] = [.left, .right]
    static let lcrRoles: [SpeakerRole] = [.left, .center, .right]
    static let fivePointRoles: [SpeakerRole] = [.left, .center, .right, .backLeft, .backRight]

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
        case .left: NormalizedPoint(x: 0.2, y: 0.18)
        case .center: NormalizedPoint(x: 0.5, y: 0.16)
        case .right: NormalizedPoint(x: 0.8, y: 0.18)
        case .backLeft: NormalizedPoint(x: 0.15, y: 0.88)
        case .backRight: NormalizedPoint(x: 0.85, y: 0.88)
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
        let left = setup.speakers.first { $0.role == .left }?.position ?? .init(x: 0.2, y: 0.18)
        let center = setup.speakers.first { $0.role == .center }?.position ?? .init(x: 0.5, y: 0.16)
        let right = setup.speakers.first { $0.role == .right }?.position ?? .init(x: 0.8, y: 0.18)
        let projection = leftRightProjection(for: cue.position, left: left, right: right)
        let pan = (projection * 2 - 1) * 100

        let centerProjection = leftRightProjection(for: center, left: left, right: right)
        let distanceFromCenter = min(abs(projection - centerProjection) / max(centerProjection, 1 - centerProjection, 0.05), 1)
        let centerDivergence = setup.speakerFormat == .lr ? 0 : (1 - distanceFromCenter) * 100

        let rearAmount = setup.speakerFormat == .fivePoint ? clamp((cue.position.y - 0.45) / 0.45, lower: 0, upper: 1) * 100 : 0
        let backRight = rearAmount * projection
        let backLeft = rearAmount * (1 - projection)
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

    private static func leftRightProjection(for point: NormalizedPoint, left: NormalizedPoint, right: NormalizedPoint) -> Double {
        let x = right.x - left.x
        let y = right.y - left.y
        let lengthSquared = max(x * x + y * y, 0.0001)
        let projected = ((point.x - left.x) * x + (point.y - left.y) * y) / lengthSquared
        return clamp(projected, lower: 0, upper: 1)
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

    var shortNumber: String {
        formatted(.number.precision(.fractionLength(2)))
    }
}

#Preview {
    ContentView()
}
