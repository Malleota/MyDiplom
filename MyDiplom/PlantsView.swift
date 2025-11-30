//
//  PlantsView.swift
//  MyDiplom
//
//  Created on 20.11.2025.
//

import SwiftUI
import UIKit

// MARK: - Plants View (Справочник)
struct PlantsView: View {
    @State private var plantTypes: [PlantTypeOut] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreatePlant = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Список растений
                if isLoading {
                    ProgressView("Загрузка растений...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text("Ошибка загрузки")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Повторить") {
                            loadPlantTypes()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if plantTypes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "leaf")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Нет растений")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(plantTypes) { plantType in
                                NavigationLink(destination: PlantDetailView(plantType: plantType)) {
                                    PlantRow(plantType: plantType)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Справочник")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreatePlant = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showCreatePlant) {
                CreatePlantView(onPlantCreated: {
                    showCreatePlant = false
                    loadPlantTypes()
                })
            }
            .task {
                loadPlantTypes()
            }
            .refreshable {
                await loadPlantTypesAsync()
            }
        }
    }
    
    private func loadPlantTypes() {
        Task {
            await loadPlantTypesAsync()
        }
    }
    
    private func loadPlantTypesAsync() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let plants = try await APIService.shared.getPlantTypes()
            await MainActor.run {
                plantTypes = plants
                isLoading = false
            }
        } catch {
            await MainActor.run {
                if let apiError = error as? APIError {
                    errorMessage = apiError.detail
                } else {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
            print("❌ Ошибка загрузки растений: \(error)")
        }
    }
}

// MARK: - Plant Row
struct PlantRow: View {
    let plantType: PlantTypeOut
    
    var body: some View {
        HStack(spacing: 12) {
            // Изображение растения
            if let imageUrl = plantType.image_url,
               let url = APIService.shared.getFullImageURL(imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 50, height: 50)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "leaf")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "leaf")
                            .foregroundColor(.gray)
                    )
            }
            
            // Информация о растении
            VStack(alignment: .leading, spacing: 4) {
                Text(plantType.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let description = plantType.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("Описание отсутствует")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Plant Detail View
struct PlantDetailView: View {
    let plantType: PlantTypeOut
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 24) {
                // Заголовок: Название и описание с картинкой
                VStack(alignment: .center, spacing: 12) {
                    if let imageUrl = plantType.image_url,
                       let url = APIService.shared.getFullImageURL(imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        }
                        .frame(width: 80, height: 80)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "leaf")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 24))
                            )
                    }
                    // Вертикальный контейнер с названием и описанием
                    VStack(alignment: .center, spacing: 0) {
                        Text(plantType.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        if let description = plantType.description, !description.isEmpty {
                            Text(description)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .padding(.horizontal)
                
                // Условия содержания
                VStack(alignment: .leading, spacing: 16) {
                    Text("Условия содержания")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    // Две карточки: температура и влажность
                    HStack(spacing: 12) {
                        // Карточка температуры
                        if let tempMin = plantType.temp_min, let tempMax = plantType.temp_max {
                            SensorDataCard(
                                icon: "thermometer",
                                title: "Температура",
                                value: "\(String(format: "%.1f", tempMin)) - \(String(format: "%.1f", tempMax))",
                                unit: "°C"
                            )
                        }
                        
                        // Карточка влажности
                        if let humMin = plantType.humidity_min, let humMax = plantType.humidity_max {
                            SensorDataCard(
                                icon: "humidity",
                                title: "Влажность",
                                value: "\(String(format: "%.0f", humMin)) - \(String(format: "%.0f", humMax))",
                                unit: "%"
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Интервалы полива и удобрения
                    if plantType.watering_interval_days != nil || plantType.fertilizing_interval_days != nil {
                        HStack(spacing: 12) {
                            // Интервал полива
                            if let wateringInterval = plantType.watering_interval_days {
                                SensorDataCard(
                                    icon: "drop",
                                    title: "Полив",
                                    value: "\(wateringInterval)",
                                    unit: " \(dayText(wateringInterval))"
                                )
                            }
                            
                            // Интервал удобрения
                            if let fertilizingInterval = plantType.fertilizing_interval_days {
                                SensorDataCard(
                                    icon: "pills",
                                    title: "Удобрение",
                                    value: "\(fertilizingInterval)",
                                    unit: " \(dayText(fertilizingInterval))"
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle(plantType.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func dayText(_ days: Int) -> String {
        let lastDigit = days % 10
        let lastTwoDigits = days % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 14 {
            return "дней"
        } else if lastDigit == 1 {
            return "день"
        } else if lastDigit >= 2 && lastDigit <= 4 {
            return "дня"
        } else {
            return "дней"
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1.0)
        )
    }
}

// MARK: - Create Plant View
struct CreatePlantView: View {
    @Environment(\.dismiss) private var dismiss
    let onPlantCreated: () -> Void
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedImageId: String? = nil
    @State private var uploadedImageUrl: String? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var tempMin: String = ""
    @State private var tempMax: String = ""
    @State private var humidityMin: String = ""
    @State private var humidityMax: String = ""
    @State private var wateringInterval: String = ""
    @State private var fertilizingInterval: String = ""
    
    @State private var availableImages: [GreenhouseImageOut] = []
    @State private var isLoadingImages = false
    @State private var isLoading = false
    @State private var isUploadingImage = false
    @State private var errorMessage: String?
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Название
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Название")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        SystemInputField(
                            placeholder: "Введите название растения",
                            text: $name
                        )
                    }
                    
                    // Описание
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Описание")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 40)
                                .fill(DesignColor.Background.primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 40)
                                        .stroke(DesignColor.Fills.tertiar, lineWidth: 1)
                                )
                                .frame(height: 120)
                            
                            if #available(iOS 16.0, *) {
                                TextEditor(text: $description)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(Color.clear)
                                    .scrollContentBackground(.hidden)
                            } else {
                                TextEditor(text: $description)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .background(Color.clear)
                            }
                        }
                    }
                    
                    // Выбор изображения
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Изображение")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        // Кнопка загрузки своего изображения
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Загрузить изображение")
                                Spacer()
                                if isUploadingImage {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if selectedImage != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DesignColor.mainAccent)
                                }
                            }
                            .padding()
                            .background(DesignColor.Background.primary)
                            .cornerRadius(40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 40)
                                    .stroke(selectedImage != nil ? DesignColor.mainAccent : DesignColor.Fills.tertiar, lineWidth: selectedImage != nil ? 2 : 1)
                            )
                        }
                        .disabled(isUploadingImage)
                        
                        // Превью загруженного изображения
                        if let selectedImage = selectedImage {
                            HStack {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Загружено")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Изображение будет загружено при создании")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    self.selectedImage = nil
                                    uploadedImageUrl = nil
                                    // Если было выбрано существующее изображение, возвращаем выбор на него
                                    if selectedImageId == nil && !availableImages.isEmpty {
                                        selectedImageId = availableImages.first?.id
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(DesignColor.Background.primary)
                            .cornerRadius(12)
                        }
                        
                        // Выбор из существующих изображений
                        if isLoadingImages {
                            ProgressView("Загрузка изображений...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if !availableImages.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Или выберите из существующих")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(availableImages) { image in
                                            Button(action: {
                                                // Снимаем выбор с загруженного изображения
                                                selectedImage = nil
                                                uploadedImageUrl = nil
                                                // Выбираем существующее изображение
                                                selectedImageId = image.id
                                            }) {
                                                Group {
                                                    if let imageUrl = APIService.shared.getFullImageURL(image.image_url) {
                                                        AsyncImage(url: imageUrl) { phase in
                                                            switch phase {
                                                            case .empty:
                                                                ProgressView()
                                                                    .frame(width: 100, height: 100)
                                                            case .success(let img):
                                                                img
                                                                    .resizable()
                                                                    .aspectRatio(contentMode: .fill)
                                                            case .failure:
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .fill(Color.gray.opacity(0.2))
                                                                    .frame(width: 100, height: 100)
                                                                    .overlay(
                                                                        Image(systemName: "photo")
                                                                            .foregroundColor(.gray)
                                                                    )
                                                            @unknown default:
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .fill(Color.gray.opacity(0.2))
                                                                    .frame(width: 100, height: 100)
                                                            }
                                                        }
                                                        .frame(width: 100, height: 100)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.gray.opacity(0.2))
                                                            .frame(width: 100, height: 100)
                                                            .overlay(
                                                                Image(systemName: "photo")
                                                                    .foregroundColor(.gray)
                                                            )
                                                    }
                                                }
                                            }
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedImageId == image.id ? DesignColor.mainAccent : Color.clear, lineWidth: 2)
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Температура
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Температура (°C)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Минимум")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SystemInputField(
                                    placeholder: "°C",
                                    text: $tempMin,
                                    keyboardType: .decimalPad
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Максимум")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SystemInputField(
                                    placeholder: "°C",
                                    text: $tempMax,
                                    keyboardType: .decimalPad
                                )
                            }
                        }
                    }
                    
                    // Влажность
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Влажность (%)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Минимум")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SystemInputField(
                                    placeholder: "%",
                                    text: $humidityMin,
                                    keyboardType: .decimalPad
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Максимум")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SystemInputField(
                                    placeholder: "%",
                                    text: $humidityMax,
                                    keyboardType: .decimalPad
                                )
                            }
                        }
                    }
                    
                    // Интервалы
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Интервалы")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Полив (дней)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SystemInputField(
                                    placeholder: "Дней",
                                    text: $wateringInterval,
                                    keyboardType: .numberPad
                                )
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Удобрение (дней)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SystemInputField(
                                    placeholder: "Дней",
                                    text: $fertilizingInterval,
                                    keyboardType: .numberPad
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Новое растение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Создать") {
                        createPlant()
                    }
                    .disabled(isLoading || name.isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage, selectedImageId: $selectedImageId)
            }
            .task {
                await loadImages()
            }
        }
    }
    
    private func loadImages() async {
        isLoadingImages = true
        defer { isLoadingImages = false }
        
        do {
            availableImages = try await APIService.shared.getGreenhouseImages()
            print("📸 loadImages: Загружено \(availableImages.count) изображений")
            
            // Предвыбираем первую картинку, если нет загруженного изображения
            if !availableImages.isEmpty && selectedImageId == nil && selectedImage == nil {
                selectedImageId = availableImages.first?.id
            }
        } catch {
            print("❌ Ошибка загрузки изображений: \(error)")
            if let apiError = error as? APIError {
                errorMessage = apiError.detail
            } else {
                errorMessage = "Ошибка загрузки изображений: \(error.localizedDescription)"
            }
        }
    }
    
    private func createPlant() {
        guard !name.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                var imageUrl: String? = nil
                
                // Если выбрано загруженное изображение, загружаем его сначала
                if let selectedImage = selectedImage {
                    isUploadingImage = true
                    defer { isUploadingImage = false }
                    
                    // Определяем формат и конвертируем UIImage в Data
                    var imageData: Data?
                    var fileExtension: String = "jpg" // Значение по умолчанию
                    
                    // Пытаемся определить формат исходного изображения
                    if let pngData = selectedImage.pngData() {
                        imageData = pngData
                        fileExtension = "png"
                    } else if let jpegData = selectedImage.jpegData(compressionQuality: 0.8) {
                        imageData = jpegData
                        fileExtension = "jpg"
                    }
                    
                    guard let finalImageData = imageData else {
                        throw APIError(detail: "Не удалось обработать изображение")
                    }
                    
                    let filename = "plant_\(UUID().uuidString).\(fileExtension)"
                    
                    print("📤 createPlant: Загрузка изображения \(filename), размер: \(finalImageData.count) байт")
                    
                    let uploadResponse = try await APIService.shared.uploadPlantImage(
                        imageData: finalImageData,
                        filename: filename
                    )
                    imageUrl = uploadResponse.image_url
                } else if let selectedImageId = selectedImageId,
                          let selectedImage = availableImages.first(where: { $0.id == selectedImageId }) {
                    imageUrl = selectedImage.image_url
                }
                
                let plant = PlantTypeCreate(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    image_url: imageUrl,
                    temp_min: Double(tempMin),
                    temp_max: Double(tempMax),
                    humidity_min: Double(humidityMin),
                    humidity_max: Double(humidityMax),
                    watering_interval_days: Int(wateringInterval),
                    fertilizing_interval_days: Int(fertilizingInterval)
                )
                
                _ = try await APIService.shared.createPlantType(plant)
                await MainActor.run {
                    isLoading = false
                    onPlantCreated()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    isUploadingImage = false
                    if let apiError = error as? APIError {
                        errorMessage = apiError.detail
                    } else {
                        let errorDescription = error.localizedDescription
                        print("❌ createPlant: Ошибка: \(error)")
                        print("❌ createPlant: Описание: \(errorDescription)")
                        errorMessage = "Ошибка: \(errorDescription)"
                    }
                }
            }
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var selectedImageId: String?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, selectedImageId: $selectedImageId)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        @Binding var selectedImageId: String?
        
        init(_ parent: ImagePicker, selectedImageId: Binding<String?>) {
            self.parent = parent
            self._selectedImageId = selectedImageId
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Снимаем выбор с существующих изображений
            selectedImageId = nil
            // Устанавливаем загруженное изображение
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

