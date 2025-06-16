import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let excludedActivityTypes: [UIActivity.ActivityType]?
    
    init(items: [Any], excludedActivityTypes: [UIActivity.ActivityType]? = nil) {
        self.items = items
        self.excludedActivityTypes = excludedActivityTypes
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        activityViewController.excludedActivityTypes = excludedActivityTypes
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

struct ExportOptionsView: View {
    let match: Match?
    let team: Team?
    let trainingSession: TrainingSession?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isExporting = false
    @State private var exportError: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Options")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.top)
                
                if let match = match {
                    matchExportOptions(match)
                } else if let team = team {
                    teamExportOptions(team)
                } else if let trainingSession = trainingSession {
                    trainingExportOptions(trainingSession)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.accent)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .alert("Export Error", isPresented: .constant(exportError != nil)) {
            Button("OK") {
                exportError = nil
            }
        } message: {
            if let error = exportError {
                Text(error)
            }
        }
    }
    
    @ViewBuilder
    private func matchExportOptions(_ match: Match) -> some View {
        VStack(spacing: 15) {
            Text("Match Report")
                .font(.headline)
                .foregroundColor(.white)
            
            exportButton(
                title: "Export as PDF",
                subtitle: "Match report with player statistics",
                icon: "doc.pdf"
            ) {
                exportMatchPDF(match)
            }
            
            exportButton(
                title: "Share Match Summary",
                subtitle: "Quick text summary for sharing",
                icon: "square.and.arrow.up"
            ) {
                shareMatchSummary(match)
            }
        }
    }
    
    @ViewBuilder
    private func teamExportOptions(_ team: Team) -> some View {
        VStack(spacing: 15) {
            Text("Team Statistics")
                .font(.headline)
                .foregroundColor(.white)
            
            exportButton(
                title: "Player Statistics CSV",
                subtitle: "Complete player statistics data",
                icon: "tablecells"
            ) {
                exportPlayerStatsCSV(team)
            }
            
            exportButton(
                title: "Match History CSV",
                subtitle: "All match results and statistics",
                icon: "calendar"
            ) {
                exportMatchHistoryCSV(team)
            }
        }
    }
    
    @ViewBuilder
    private func trainingExportOptions(_ session: TrainingSession) -> some View {
        VStack(spacing: 15) {
            Text("Training Session")
                .font(.headline)
                .foregroundColor(.white)
            
            exportButton(
                title: "Export as PDF",
                subtitle: "Training session report with attendance",
                icon: "doc.pdf"
            ) {
                exportTrainingPDF(session)
            }
        }
    }
    
    private func exportButton(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accent)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.accent)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(12)
        }
        .disabled(isExporting)
    }
    
    // MARK: - Export Functions
    
    private func exportMatchPDF(_ match: Match) {
        isExporting = true
        
        Task {
            do {
                if let pdfData = ExportService.shared.generateMatchReportPDF(for: match) {
                    let fileName = "Match_Report_\(match.team?.name ?? "Team")_\(formatDateForFilename(match.date)).pdf"
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    
                    try pdfData.write(to: tempURL)
                    
                    await MainActor.run {
                        shareItems = [tempURL]
                        showingShareSheet = true
                        isExporting = false
                    }
                } else {
                    await MainActor.run {
                        exportError = "Failed to generate PDF report"
                        isExporting = false
                    }
                }
            } catch {
                await MainActor.run {
                    exportError = "Error creating PDF: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
    
    private func exportTrainingPDF(_ session: TrainingSession) {
        isExporting = true
        
        Task {
            do {
                if let pdfData = ExportService.shared.generateTrainingSessionPDF(for: session) {
                    let fileName = "Training_Session_\(session.title ?? "Session")_\(formatDateForFilename(session.date)).pdf"
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    
                    try pdfData.write(to: tempURL)
                    
                    await MainActor.run {
                        shareItems = [tempURL]
                        showingShareSheet = true
                        isExporting = false
                    }
                } else {
                    await MainActor.run {
                        exportError = "Failed to generate PDF report"
                        isExporting = false
                    }
                }
            } catch {
                await MainActor.run {
                    exportError = "Error creating PDF: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
    
    private func exportPlayerStatsCSV(_ team: Team) {
        isExporting = true
        
        Task {
            do {
                let csvContent = ExportService.shared.generatePlayerStatisticsCSV(for: team)
                let fileName = "Player_Statistics_\(team.name ?? "Team").csv"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
                
                await MainActor.run {
                    shareItems = [tempURL]
                    showingShareSheet = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = "Error creating CSV: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
    
    private func exportMatchHistoryCSV(_ team: Team) {
        isExporting = true
        
        Task {
            do {
                let csvContent = ExportService.shared.generateMatchHistoryCSV(for: team)
                let fileName = "Match_History_\(team.name ?? "Team").csv"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
                
                await MainActor.run {
                    shareItems = [tempURL]
                    showingShareSheet = true
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    exportError = "Error creating CSV: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }
    
    private func shareMatchSummary(_ match: Match) {
        let stats = match.playerStats as? Set<PlayerStats> ?? []
        let totalGoals = stats.reduce(0) { $0 + Int($1.goals) }
        let totalAssists = stats.reduce(0) { $0 + Int($1.assists) }
        let playersUsed = stats.count
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let summary = """
        🏆 Match Summary - \(match.team?.name ?? "Team")
        
        📅 Date: \(match.date.map { dateFormatter.string(from: $0) } ?? "N/A")
        ⏱️ Duration: \(match.duration) minutes
        🥅 Total Goals: \(totalGoals)
        🎯 Total Assists: \(totalAssists)
        👥 Players Used: \(playersUsed)
        
        Generated by SubSoccer
        """
        
        shareItems = [summary]
        showingShareSheet = true
    }
    
    private func formatDateForFilename(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}