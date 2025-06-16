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
        
        UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, nil)
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // A4 size
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDFContext()
            return nil
        }
        
        drawMatchReportContent(context: context, match: match, pageRect: pageRect)
        
        UIGraphicsEndPDFContext()
        
        return pdfData as Data
    }
    
    private func drawMatchReportContent(context: CGContext, match: Match, pageRect: CGRect) {
        let margin: CGFloat = 50
        var yPosition: CGFloat = margin
        
        // Add modern header with accent color stripe
        context.setFillColor(red: 0, green: 1, blue: 0, alpha: 1) // Lime green
        context.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: 8))
        
        yPosition += 20
        
        // App branding
        let brandText = "SubSoccer"
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.systemGray
        ]
        let brandSize = brandText.size(withAttributes: brandAttributes)
        let brandRect = CGRect(x: pageRect.width - margin - brandSize.width, y: yPosition, width: brandSize.width, height: brandSize.height)
        brandText.draw(in: brandRect, withAttributes: brandAttributes)
        
        yPosition += 30
        
        // Title with modern styling
        let titleText = "⚽ MATCH REPORT"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: UIColor.black
        ]
        let titleSize = titleText.size(withAttributes: titleAttributes)
        let titleRect = CGRect(x: (pageRect.width - titleSize.width) / 2, y: yPosition, width: titleSize.width, height: titleSize.height)
        titleText.draw(in: titleRect, withAttributes: titleAttributes)
        yPosition += titleSize.height + 40
        
        // Team name with background
        let teamName = "🏆 " + (match.team?.name ?? "Unknown Team")
        let teamAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.white
        ]
        let teamSize = teamName.size(withAttributes: teamAttributes)
        let teamBgRect = CGRect(x: margin - 10, y: yPosition - 5, width: teamSize.width + 20, height: teamSize.height + 10)
        
        // Draw team name background
        context.setFillColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        context.fill(teamBgRect)
        context.setStrokeColor(red: 0, green: 1, blue: 0, alpha: 1)
        context.setLineWidth(2)
        context.stroke(teamBgRect)
        
        let teamRect = CGRect(x: margin, y: yPosition, width: teamSize.width, height: teamSize.height)
        teamName.draw(in: teamRect, withAttributes: teamAttributes)
        yPosition += teamSize.height + 30
        
        // Match details in professional cards
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        let matchDetails = [
            ("📅", "Date", match.date.map { dateFormatter.string(from: $0) } ?? "N/A"),
            ("⏱️", "Duration", "\(match.duration) minutes"),
            ("🏃", "Halves", "\(match.numberOfHalves)"),
            ("⚡", "Overtime", match.hasOvertime ? "Enabled" : "Disabled")
        ]
        
        let cardWidth: CGFloat = (pageRect.width - 3 * margin) / 2
        let cardHeight: CGFloat = 60
        
        for (index, detail) in matchDetails.enumerated() {
            let row = index / 2
            let col = index % 2
            let cardX = margin + CGFloat(col) * (cardWidth + margin)
            let cardY = yPosition + CGFloat(row) * (cardHeight + 15)
            
            let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
            
            // Draw card background
            context.setFillColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)
            context.fill(cardRect)
            context.setStrokeColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
            context.setLineWidth(1)
            context.stroke(cardRect)
            
            // Draw icon and text
            let iconRect = CGRect(x: cardX + 10, y: cardY + 10, width: 20, height: 20)
            detail.0.draw(in: iconRect, withAttributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ])
            
            let labelRect = CGRect(x: cardX + 35, y: cardY + 8, width: cardWidth - 45, height: 18)
            detail.1.draw(in: labelRect, withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ])
            
            let valueRect = CGRect(x: cardX + 35, y: cardY + 26, width: cardWidth - 45, height: 20)
            detail.2.draw(in: valueRect, withAttributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ])
        }
        
        yPosition += CGFloat((matchDetails.count + 1) / 2) * (cardHeight + 15) + 20
        
        yPosition += 30
        
        // Player statistics header with modern styling
        yPosition += 20
        let statsHeaderText = "📊 PLAYER STATISTICS"
        let statsHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]
        let statsHeaderSize = statsHeaderText.size(withAttributes: statsHeaderAttributes)
        let statsHeaderRect = CGRect(x: margin, y: yPosition, width: statsHeaderSize.width, height: statsHeaderSize.height)
        
        // Add header underline
        context.setStrokeColor(red: 0, green: 1, blue: 0, alpha: 1)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: margin, y: yPosition + statsHeaderSize.height + 5))
        context.addLine(to: CGPoint(x: margin + 200, y: yPosition + statsHeaderSize.height + 5))
        context.strokePath()
        
        statsHeaderText.draw(in: statsHeaderRect, withAttributes: statsHeaderAttributes)
        yPosition += statsHeaderSize.height + 25
        
        // Modern table with header background
        let headers = ["👤 Player", "📍 Position", "#", "⏱️ Minutes", "⚽ Goals", "🎯 Assists"]
        let columnWidths: [CGFloat] = [140, 90, 40, 70, 70, 70]
        var xPosition: CGFloat = margin
        
        // Draw header background
        let headerBgRect = CGRect(x: margin, y: yPosition, width: columnWidths.reduce(0, +), height: 30)
        context.setFillColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        context.fill(headerBgRect)
        context.setStrokeColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
        context.setLineWidth(1)
        context.stroke(headerBgRect)
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        for (index, header) in headers.enumerated() {
            let headerRect = CGRect(x: xPosition + 5, y: yPosition + 8, width: columnWidths[index] - 10, height: 16)
            header.draw(in: headerRect, withAttributes: headerAttributes)
            
            // Draw vertical separator
            if index < headers.count - 1 {
                context.setStrokeColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
                context.setLineWidth(0.5)
                context.move(to: CGPoint(x: xPosition + columnWidths[index], y: yPosition))
                context.addLine(to: CGPoint(x: xPosition + columnWidths[index], y: yPosition + 30))
                context.strokePath()
            }
            
            xPosition += columnWidths[index]
        }
        
        yPosition += 35
        
        // Player statistics data with alternating row colors
        let playerStats = (match.playerStats as? Set<PlayerStats>)?.sorted { 
            Int($0.minutesPlayed) > Int($1.minutesPlayed)
        } ?? []
        
        let dataAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        
        for (rowIndex, stat) in playerStats.enumerated() {
            guard let player = stat.player else { continue }
            
            // Alternating row background
            if rowIndex % 2 == 1 {
                let rowBgRect = CGRect(x: margin, y: yPosition, width: columnWidths.reduce(0, +), height: 25)
                context.setFillColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
                context.fill(rowBgRect)
            }
            
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
                let dataRect = CGRect(x: xPosition + 5, y: yPosition + 5, width: columnWidths[index] - 10, height: 15)
                data.draw(in: dataRect, withAttributes: dataAttributes)
                
                // Draw vertical separator
                if index < rowData.count - 1 {
                    context.setStrokeColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
                    context.setLineWidth(0.3)
                    context.move(to: CGPoint(x: xPosition + columnWidths[index], y: yPosition))
                    context.addLine(to: CGPoint(x: xPosition + columnWidths[index], y: yPosition + 25))
                    context.strokePath()
                }
                
                xPosition += columnWidths[index]
            }
            
            // Draw horizontal separator
            context.setStrokeColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
            context.setLineWidth(0.3)
            context.move(to: CGPoint(x: margin, y: yPosition + 25))
            context.addLine(to: CGPoint(x: margin + columnWidths.reduce(0, +), y: yPosition + 25))
            context.strokePath()
            
            yPosition += 25
        }
        
        // Summary statistics in attractive cards
        yPosition += 30
        let totalGoals = playerStats.reduce(0) { $0 + Int($1.goals) }
        let totalAssists = playerStats.reduce(0) { $0 + Int($1.assists) }
        let totalPlayers = playerStats.count
        
        let summaryTitle = "📈 MATCH SUMMARY"
        let summaryTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        let summaryTitleSize = summaryTitle.size(withAttributes: summaryTitleAttributes)
        let summaryTitleRect = CGRect(x: margin, y: yPosition, width: summaryTitleSize.width, height: summaryTitleSize.height)
        summaryTitle.draw(in: summaryTitleRect, withAttributes: summaryTitleAttributes)
        
        yPosition += summaryTitleSize.height + 15
        
        // Summary cards
        let summaryData = [
            ("⚽", "Total Goals", "\(totalGoals)"),
            ("🎯", "Total Assists", "\(totalAssists)"),
            ("👥", "Players Used", "\(totalPlayers)")
        ]
        
        let summaryCardWidth: CGFloat = (pageRect.width - 4 * margin) / 3
        
        for (index, data) in summaryData.enumerated() {
            let cardX = margin + CGFloat(index) * (summaryCardWidth + margin)
            let cardRect = CGRect(x: cardX, y: yPosition, width: summaryCardWidth, height: 50)
            
            // Draw card with lime accent
            context.setFillColor(red: 0, green: 1, blue: 0, alpha: 0.1)
            context.fill(cardRect)
            context.setStrokeColor(red: 0, green: 1, blue: 0, alpha: 0.3)
            context.setLineWidth(1)
            context.stroke(cardRect)
            
            // Icon
            let iconRect = CGRect(x: cardX + 8, y: yPosition + 8, width: 15, height: 15)
            data.0.draw(in: iconRect, withAttributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ])
            
            // Value
            let valueRect = CGRect(x: cardX + 25, y: yPosition + 5, width: summaryCardWidth - 35, height: 20)
            data.2.draw(in: valueRect, withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ])
            
            // Label
            let labelRect = CGRect(x: cardX + 25, y: yPosition + 25, width: summaryCardWidth - 35, height: 15)
            data.1.draw(in: labelRect, withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ])
        }
        
        // Footer
        yPosition += 80
        let footerText = "Generated by SubSoccer • \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.lightGray
        ]
        let footerSize = footerText.size(withAttributes: footerAttributes)
        let footerRect = CGRect(x: (pageRect.width - footerSize.width) / 2, y: yPosition, width: footerSize.width, height: footerSize.height)
        footerText.draw(in: footerRect, withAttributes: footerAttributes)
    }
    
    // MARK: - CSV Export
    
    func generatePlayerStatisticsCSV(for team: Team) -> String {
        // Professional CSV with team header and metadata
        var csvContent = "# SubSoccer Player Statistics Report\n"
        csvContent += "# Team: \(team.name ?? "Unknown Team")\n"
        csvContent += "# Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))\n"
        csvContent += "# \n"
        csvContent += "Player Name,Position,Jersey Number,Total Minutes,Average Minutes per Match,Total Goals,Goals per Match,Total Assists,Assists per Match,Matches Played,Goals + Assists\n"
        
        let players = (team.players as? Set<Player>)?.sorted { 
            let stats1 = $0.statistics as? Set<PlayerStats> ?? []
            let stats2 = $1.statistics as? Set<PlayerStats> ?? []
            let total1 = stats1.reduce(0) { $0 + Int($1.goals) + Int($1.assists) }
            let total2 = stats2.reduce(0) { $0 + Int($1.goals) + Int($1.assists) }
            return total1 > total2
        } ?? []
        
        for player in players {
            let stats = player.statistics as? Set<PlayerStats> ?? []
            let totalMinutes = stats.reduce(0) { $0 + Int($1.minutesPlayed) }
            let totalGoals = stats.reduce(0) { $0 + Int($1.goals) }
            let totalAssists = stats.reduce(0) { $0 + Int($1.assists) }
            let matchesPlayed = stats.count
            let avgMinutes = matchesPlayed > 0 ? Double(totalMinutes) / Double(matchesPlayed) : 0
            let goalsPerMatch = matchesPlayed > 0 ? Double(totalGoals) / Double(matchesPlayed) : 0
            let assistsPerMatch = matchesPlayed > 0 ? Double(totalAssists) / Double(matchesPlayed) : 0
            let totalContributions = totalGoals + totalAssists
            
            let row = "\"\(player.name ?? "")\",\"\(player.position ?? "")\",\(player.jerseyNumber),\(totalMinutes),\(String(format: "%.1f", avgMinutes)),\(totalGoals),\(String(format: "%.2f", goalsPerMatch)),\(totalAssists),\(String(format: "%.2f", assistsPerMatch)),\(matchesPlayed),\(totalContributions)\n"
            csvContent += row
        }
        
        return csvContent
    }
    
    func generateMatchHistoryCSV(for team: Team) -> String {
        // Professional CSV with enhanced match data
        var csvContent = "# SubSoccer Match History Report\n"
        csvContent += "# Team: \(team.name ?? "Unknown Team")\n"
        csvContent += "# Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short))\n"
        csvContent += "# \n"
        csvContent += "Match Date,Day of Week,Duration (min),Halves,Overtime,Total Goals,Goals per Half,Total Assists,Assists per Half,Players Used,Goal + Assist Total,Average Minutes per Player\n"
        
        let matches = (team.matches as? Set<Match>)?.sorted { 
            ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast)
        } ?? []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        
        for match in matches {
            let stats = match.playerStats as? Set<PlayerStats> ?? []
            let totalGoals = stats.reduce(0) { $0 + Int($1.goals) }
            let totalAssists = stats.reduce(0) { $0 + Int($1.assists) }
            let totalMinutes = stats.reduce(0) { $0 + Int($1.minutesPlayed) }
            let playersUsed = stats.count
            let goalsPerHalf = match.numberOfHalves > 0 ? Double(totalGoals) / Double(match.numberOfHalves) : 0
            let assistsPerHalf = match.numberOfHalves > 0 ? Double(totalAssists) / Double(match.numberOfHalves) : 0
            let avgMinutesPerPlayer = playersUsed > 0 ? Double(totalMinutes) / Double(playersUsed) : 0
            let totalContributions = totalGoals + totalAssists
            
            let dateString = match.date.map { dateFormatter.string(from: $0) } ?? ""
            let dayString = match.date.map { dayFormatter.string(from: $0) } ?? ""
            
            let row = "\"\(dateString)\",\"\(dayString)\",\(match.duration),\(match.numberOfHalves),\(match.hasOvertime ? "Yes" : "No"),\(totalGoals),\(String(format: "%.2f", goalsPerHalf)),\(totalAssists),\(String(format: "%.2f", assistsPerHalf)),\(playersUsed),\(totalContributions),\(String(format: "%.1f", avgMinutesPerPlayer))\n"
            csvContent += row
        }
        
        return csvContent
    }
    
    // MARK: - Training Session Export
    
    func generateTrainingSessionPDF(for session: TrainingSession) -> Data? {
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, nil)
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDFContext()
            return nil
        }
        
        drawTrainingSessionContent(context: context, session: session, pageRect: pageRect)
        
        UIGraphicsEndPDFContext()
        
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