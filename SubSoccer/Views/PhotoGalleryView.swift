import SwiftUI
import PhotosUI
import CoreData

struct PhotoGalleryView: View {
    @ObservedObject var session: TrainingSession
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var photoService = PhotoService.shared
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var showingPhotoDetail: TrainingPhoto?
    @State private var isAddingPhoto = false
    
    private var photos: [TrainingPhoto] {
        (session.photos as? Set<TrainingPhoto>)?.sorted { 
            ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast)
        } ?? []
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                if photos.isEmpty {
                    emptyStateView
                } else {
                    photoGridView
                }
            }
            .navigationTitle("Training Photos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            if let newValue = newValue {
                loadSelectedPhoto(newValue)
            }
        }
        .sheet(item: $showingPhotoDetail) { photo in
            PhotoDetailView(photo: photo, session: session)
        }
        .overlay {
            if isAddingPhoto {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    ProgressView("Adding Photo...")
                        .padding()
                        .background(AppTheme.secondaryBackground)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.secondaryText)
            
            VStack(spacing: 8) {
                Text("No Photos Yet")
                    .font(AppTheme.subheadFont)
                    .foregroundColor(AppTheme.primaryText)
                
                Text("Add photos to capture memories from this training session")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add First Photo")
                }
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(.white)
                .padding()
                .background(AppTheme.accentColor)
                .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var photoGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ], spacing: 4) {
                ForEach(photos, id: \.objectID) { photo in
                    PhotoThumbnailView(photo: photo)
                        .onTapGesture {
                            showingPhotoDetail = photo
                        }
                }
            }
            .padding()
        }
    }
    
    private func loadSelectedPhoto(_ item: PhotosPickerItem) {
        isAddingPhoto = true
        
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    
                    await MainActor.run {
                        _ = photoService.addPhoto(
                            to: session,
                            image: image,
                            in: viewContext
                        )
                        selectedPhoto = nil
                        isAddingPhoto = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("Failed to load photo: \(error)")
                    isAddingPhoto = false
                }
            }
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: TrainingPhoto
    @StateObject private var photoService = PhotoService.shared
    
    var body: some View {
        ZStack {
            if let thumbnail = photoService.thumbnailFromPhoto(photo) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(AppTheme.secondaryBackground)
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(AppTheme.secondaryText)
                    )
            }
            
            // Caption overlay
            if let caption = photo.caption, !caption.isEmpty {
                VStack {
                    Spacer()
                    
                    HStack {
                        Text(caption)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    .padding(.horizontal, 4)
                }
            }
            
            // Player tags indicator
            if let taggedPlayers = photo.taggedPlayers as? Set<Player>, !taggedPlayers.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(AppTheme.accentColor)
                            .clipShape(Circle())
                    }
                    .padding(.top, 4)
                    .padding(.trailing, 4)
                    
                    Spacer()
                }
            }
        }
    }
}

struct PhotoDetailView: View {
    @ObservedObject var photo: TrainingPhoto
    let session: TrainingSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var photoService = PhotoService.shared
    @State private var caption: String = ""
    @State private var showingPlayerTagging = false
    @State private var showingDeleteAlert = false
    @State private var isEditingCaption = false
    
    private var taggedPlayers: [Player] {
        (photo.taggedPlayers as? Set<Player>)?.sorted { 
            ($0.name ?? "") < ($1.name ?? "") 
        } ?? []
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Photo
                        photoView
                        
                        // Caption section
                        captionSection
                        
                        // Tagged players section
                        taggedPlayersSection
                        
                        // Actions
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Tag Players") {
                            showingPlayerTagging = true
                        }
                        
                        Button("Edit Caption") {
                            isEditingCaption = true
                            caption = photo.caption ?? ""
                        }
                        
                        Button("Delete Photo", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppTheme.accentColor)
                    }
                }
            }
        }
        .onAppear {
            caption = photo.caption ?? ""
        }
        .sheet(isPresented: $showingPlayerTagging) {
            PlayerTaggingView(photo: photo, session: session)
        }
        .alert("Delete Photo", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this photo? This action cannot be undone.")
        }
        .alert("Edit Caption", isPresented: $isEditingCaption) {
            TextField("Caption", text: $caption)
            Button("Save") {
                updateCaption()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var photoView: some View {
        Group {
            if let fullImage = photoService.fullSizeImageFromPhoto(photo) {
                Image(uiImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(AppTheme.secondaryBackground)
                    .frame(height: 300)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.secondaryText)
                    )
            }
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Caption")
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(AppTheme.primaryText)
            
            if let caption = photo.caption, !caption.isEmpty {
                Text(caption)
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.primaryText)
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(8)
            } else {
                Text("No caption")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var taggedPlayersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tagged Players")
                .font(AppTheme.bodyFont.bold())
                .foregroundColor(AppTheme.primaryText)
            
            if taggedPlayers.isEmpty {
                Text("No players tagged")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.secondaryText)
                    .italic()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(taggedPlayers, id: \.objectID) { player in
                        PlayerTagView(player: player)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: saveToPhotoLibrary) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save to Photos")
                }
                .font(AppTheme.bodyFont)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accentColor)
                .cornerRadius(12)
            }
        }
    }
    
    private func updateCaption() {
        photoService.updatePhotoCaption(photo, caption: caption, in: viewContext)
    }
    
    private func deletePhoto() {
        photoService.deletePhoto(photo, in: viewContext)
        dismiss()
    }
    
    private func saveToPhotoLibrary() {
        guard let image = photoService.fullSizeImageFromPhoto(photo) else { return }
        
        Task {
            let success = await photoService.saveToPhotoLibrary(image)
            if success {
                // Could show success feedback here
            }
        }
    }
}

struct PlayerTagView: View {
    let player: Player
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppTheme.accentColor.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(player.jerseyNumber)")
                        .font(.caption2.bold())
                        .foregroundColor(AppTheme.primaryText)
                )
            
            Text(player.name ?? "Unknown")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.primaryText)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.secondaryBackground)
        .cornerRadius(6)
    }
}

struct PlayerTaggingView: View {
    @ObservedObject var photo: TrainingPhoto
    let session: TrainingSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject private var photoService = PhotoService.shared
    @State private var selectedPlayers: Set<Player> = []
    
    private var availablePlayers: [Player] {
        (session.team?.players as? Set<Player>)?.sorted { 
            ($0.name ?? "") < ($1.name ?? "") 
        } ?? []
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.primaryBackground
                    .ignoresSafeArea()
                
                List {
                    ForEach(availablePlayers, id: \.objectID) { player in
                        PlayerSelectionRow(
                            player: player,
                            isSelected: selectedPlayers.contains(player)
                        ) {
                            if selectedPlayers.contains(player) {
                                selectedPlayers.remove(player)
                            } else {
                                selectedPlayers.insert(player)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .background(AppTheme.primaryBackground)
            }
            .navigationTitle("Tag Players")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTags()
                    }
                    .foregroundColor(AppTheme.accentColor)
                }
            }
        }
        .onAppear {
            selectedPlayers = Set(photo.taggedPlayers as? Set<Player> ?? [])
        }
    }
    
    private func saveTags() {
        photoService.tagPlayers(Array(selectedPlayers), in: photo, context: viewContext)
        dismiss()
    }
}

struct PlayerSelectionRow: View {
    let player: Player
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Circle()
                    .fill(AppTheme.accentColor.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(player.jerseyNumber)")
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.primaryText)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name ?? "Unknown")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.primaryText)
                    
                    Text(player.position ?? "N/A")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppTheme.accentColor : AppTheme.secondaryText)
                    .font(.title3)
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(AppTheme.primaryBackground)
    }
}