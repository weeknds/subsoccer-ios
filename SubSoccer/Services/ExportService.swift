import Foundation
import PDFKit
import UIKit
import CoreData

class ExportService: ObservableObject {
    static let shared = ExportService()
    
    private init() {}
    
    // MARK: - PDF Export
    
    func generateMatchReportPDF(for match: Match) -> Data? {
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFDataRepeatation(pdfData)
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // A4 size
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDF()
            return nil
        }
        
        drawMatchReportContent(context: context, match: match, pageRect: pageRect)
        
        UIGraphicsEndPDF()
        
        return pdfData as Data
    }
    
    private func drawMatchReportContent(context: CGContext, match: Match, pageRect: CGRect) {
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        
        // Title
        let titleText = "Match Report"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let titleSize = titleText.size(withAttributes: titleAttributes)
        let titleRect = CGRect(x: (pageRect.width - titleSize.width) / 2, y: yPosition, width: titleSize.width, height: titleSize.height)
        titleText.draw(in: titleRect, withAttributes: titleAttributes)
        yPosition += titleSize.height + 30
        
        // Team name
        let teamName = match.team?.name ?? "Unknown Team"
        let teamAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        let teamSize = teamName.size(withAttributes: teamAttributes)
        let teamRect = CGRect(x: margin, y: yPosition, width: teamSize.width, height: teamSize.height)
        teamName.draw(in: teamRect, withAttributes: teamAttributes)
        yPosition += teamSize.height + 20
        
        // Match details
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let matchDetails = [
            "Date: \(match.date.map { dateFormatter.string(from: $0) } ?? "N/A")",
            "Duration: \(match.duration) minutes",
            "Halves: \(match.numberOfHalves)",
            "Overtime: \(match.hasOvertime ? "Yes" : "No")"
        ]
        
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        for detail in matchDetails {
            let detailSize = detail.size(withAttributes: detailAttributes)
            let detailRect = CGRect(x: margin, y: yPosition, width: detailSize.width, height: detailSize.height)
            detail.draw(in: detailRect, withAttributes: detailAttributes)
            yPosition += detailSize.height + 5
        }
        
        yPosition += 30
        
        // Player statistics header
        let statsHeaderText = "Player Statistics"
        let statsHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        let statsHeaderSize = statsHeaderText.size(withAttributes: statsHeaderAttributes)
        let statsHeaderRect = CGRect(x: margin, y: yPosition, width: statsHeaderSize.width, height: statsHeaderSize.height)
        statsHeaderText.draw(in: statsHeaderRect, withAttributes: statsHeaderAttributes)
        yPosition += statsHeaderSize.height + 20
        
        // Table headers
        let headers = ["Player", "Position", "#", "Minutes", "Goals", "Assists"]
        let columnWidths: [CGFloat] = [120, 80, 40, 60, 60, 60]
        var xPosition: CGFloat = margin
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        for (index, header) in headers.enumerated() {
            let headerRect = CGRect(x: xPosition, y: yPosition, width: columnWidths[index], height: 20)
            header.draw(in: headerRect, withAttributes: headerAttributes)
            xPosition += columnWidths[index]
        }
        
        yPosition += 25
        
        // Draw horizontal line
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: yPosition))
        context.addLine(to: CGPoint(x: pageRect.width - margin, y: yPosition))
        context.strokePath()
        
        yPosition += 10
        
        // Player statistics data
        let playerStats = (match.playerStats as? Set<PlayerStats>)?.sorted { 
            ($0.player?.name ?? "") < ($1.player?.name ?? "") 
        } ?? []
        
        let dataAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        
        for stat in playerStats {
            guard let player = stat.player else { continue }
            
            xPosition = margin
            let rowData = [
                player.name ?? "Unknown",
                player.position ?? "N/A",
                "#\(player.jerseyNumber)",
                "\(stat.minutesPlayed)",
                "\(stat.goals)",
                "\(stat.assists)"
            ]
            
            for (index, data) in rowData.enumerated() {
                let dataRect = CGRect(x: xPosition, y: yPosition, width: columnWidths[index], height: 15)
                data.draw(in: dataRect, withAttributes: dataAttributes)
                xPosition += columnWidths[index]
            }
            
            yPosition += 18
        }
        
        // Summary statistics
        yPosition += 30
        let totalGoals = playerStats.reduce(0) { $0 + Int($1.goals) }
        let totalAssists = playerStats.reduce(0) { $0 + Int($1.assists) }
        
        let summaryText = "Team Summary - Total Goals: \(totalGoals), Total Assists: \(totalAssists)"
        let summaryAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        let summarySize = summaryText.size(withAttributes: summaryAttributes)
        let summaryRect = CGRect(x: margin, y: yPosition, width: summarySize.width, height: summarySize.height)
        summaryText.draw(in: summaryRect, withAttributes: summaryAttributes)
    }
    
    // MARK: - CSV Export
    
    func generatePlayerStatisticsCSV(for team: Team) -> String {
        var csvContent = "Player Name,Position,Jersey Number,Total Minutes,Total Goals,Total Assists,Matches Played\n"
        
        let players = (team.players as? Set<Player>)?.sorted { 
            ($0.name ?? "") < ($1.name ?? "") 
        } ?? []
        
        for player in players {
            let stats = player.statistics as? Set<PlayerStats> ?? []
            let totalMinutes = stats.reduce(0) { $0 + Int($1.minutesPlayed) }
            let totalGoals = stats.reduce(0) { $0 + Int($1.goals) }
            let totalAssists = stats.reduce(0) { $0 + Int($1.assists) }
            let matchesPlayed = stats.count
            
            let row = "\"\(player.name ?? "")\",\"\(player.position ?? "")\",\(player.jerseyNumber),\(totalMinutes),\(totalGoals),\(totalAssists),\(matchesPlayed)\n"
            csvContent += row
        }
        
        return csvContent
    }
    
    func generateMatchHistoryCSV(for team: Team) -> String {
        var csvContent = "Date,Duration (minutes),Halves,Overtime,Total Goals,Total Assists,Players Used\n"
        
        let matches = (team.matches as? Set<Match>)?.sorted { 
            ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast)
        } ?? []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for match in matches {
            let stats = match.playerStats as? Set<PlayerStats> ?? []
            let totalGoals = stats.reduce(0) { $0 + Int($1.goals) }
            let totalAssists = stats.reduce(0) { $0 + Int($1.assists) }
            let playersUsed = stats.count
            
            let dateString = match.date.map { dateFormatter.string(from: $0) } ?? ""
            let row = "\"\(dateString)\",\(match.duration),\(match.numberOfHalves),\(match.hasOvertime ? "Yes" : "No"),\(totalGoals),\(totalAssists),\(playersUsed)\n"
            csvContent += row
        }
        
        return csvContent
    }
    
    // MARK: - Training Session Export
    
    func generateTrainingSessionPDF(for session: TrainingSession) -> Data? {
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFDataRepeatation(pdfData)
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDF()
            return nil
        }
        
        drawTrainingSessionContent(context: context, session: session, pageRect: pageRect)
        
        UIGraphicsEndPDF()
        
        return pdfData as Data
    }
    
    private func drawTrainingSessionContent(context: CGContext, session: TrainingSession, pageRect: CGRect) {
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        
        // Title
        let titleText = "Training Session Report"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let titleSize = titleText.size(withAttributes: titleAttributes)
        let titleRect = CGRect(x: (pageRect.width - titleSize.width) / 2, y: yPosition, width: titleSize.width, height: titleSize.height)
        titleText.draw(in: titleRect, withAttributes: titleAttributes)
        yPosition += titleSize.height + 30
        
        // Session details
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        let sessionDetails = [
            "Title: \(session.title ?? "Training Session")",
            "Team: \(session.team?.name ?? "Unknown Team")",
            "Date: \(session.date.map { dateFormatter.string(from: $0) } ?? "N/A")",
            "Duration: \(session.duration) minutes",
            "Location: \(session.location ?? "N/A")",
            "Type: \(session.type ?? "General Training")"
        ]
        
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        for detail in sessionDetails {
            let detailSize = detail.size(withAttributes: detailAttributes)
            let detailRect = CGRect(x: margin, y: yPosition, width: detailSize.width, height: detailSize.height)
            detail.draw(in: detailRect, withAttributes: detailAttributes)
            yPosition += detailSize.height + 8
        }
        
        // Notes section
        if let notes = session.notes, !notes.isEmpty {
            yPosition += 20
            let notesHeaderText = "Notes:"
            let notesHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            let notesHeaderSize = notesHeaderText.size(withAttributes: notesHeaderAttributes)
            let notesHeaderRect = CGRect(x: margin, y: yPosition, width: notesHeaderSize.width, height: notesHeaderSize.height)
            notesHeaderText.draw(in: notesHeaderRect, withAttributes: notesHeaderAttributes)
            yPosition += notesHeaderSize.height + 10
            
            let notesRect = CGRect(x: margin, y: yPosition, width: pageRect.width - 2 * margin, height: 100)
            notes.draw(in: notesRect, withAttributes: detailAttributes)
            yPosition += 120
        }
        
        // Attendance section
        yPosition += 20
        let attendanceHeaderText = "Attendance"
        let attendanceHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        let attendanceHeaderSize = attendanceHeaderText.size(withAttributes: attendanceHeaderAttributes)
        let attendanceHeaderRect = CGRect(x: margin, y: yPosition, width: attendanceHeaderSize.width, height: attendanceHeaderSize.height)
        attendanceHeaderText.draw(in: attendanceHeaderRect, withAttributes: attendanceHeaderAttributes)
        yPosition += attendanceHeaderSize.height + 15
        
        let attendanceRecords = (session.attendanceRecords as? Set<TrainingAttendance>)?.sorted {
            ($0.player?.name ?? "") < ($1.player?.name ?? "")
        } ?? []
        
        for record in attendanceRecords {
            guard let player = record.player else { continue }
            
            let status = record.isPresent ? "✓ Present" : "✗ Absent"
            let attendanceText = "\(player.name ?? "Unknown") (#\(player.jerseyNumber)) - \(status)"
            
            let attendanceSize = attendanceText.size(withAttributes: detailAttributes)
            let attendanceRect = CGRect(x: margin + 20, y: yPosition, width: attendanceSize.width, height: attendanceSize.height)
            attendanceText.draw(in: attendanceRect, withAttributes: detailAttributes)
            yPosition += attendanceSize.height + 5
            
            if let notes = record.notes, !notes.isEmpty {
                let noteText = "   Note: \(notes)"
                let noteSize = noteText.size(withAttributes: detailAttributes)
                let noteRect = CGRect(x: margin + 20, y: yPosition, width: noteSize.width, height: noteSize.height)
                noteText.draw(in: noteRect, withAttributes: detailAttributes)
                yPosition += noteSize.height + 5
            }
        }
    }
}