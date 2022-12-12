//
//  ContentView.swift
//  calorie-tracker
//
//  Created by David Patterson-Cole on 2022-12-09.
//

import SwiftUI
import PhotosUI

// MARK: Model

struct ModelOutput: Codable {
    var data: [top1]
    var is_generating: Bool
    var duration, average_duration: Double
}

struct top1: Codable {
    var label: String
    var confidences: [top5]
}

struct top5: Codable {
    var label: String
    var confidence: Double
}

struct ImageText: Codable {
    let data: [String]
}

struct NutrionixQuery: Codable {
    let query: String
}

struct NutrionixResult: Codable {
    var foods: [NutrionixFood]
}

struct NutrionixFood: Codable {
    var food_name: String
    var nf_calories: Double
}

// MARK: Extensions

extension UIImage {
    var base64: String? {
        self.jpegData(compressionQuality: 1)?.base64EncodedString()
    }
}

// MARK: View Model

func mlPredict (image: ImageText) async -> ModelOutput? {
    guard let imageData = try? JSONEncoder().encode(image) else {
        return nil
    }
    
    let url = URL(string: "https://dpc7-food-101.hf.space/run/predict")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        let (data, response) = try await URLSession.shared.upload(for: request, from: imageData, delegate: nil)
        let decoder = JSONDecoder()
        do {
            let decodedValue = try decoder.decode(ModelOutput.self, from: data)
            return decodedValue
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }
    catch {
        print("Error")
        return nil
    }
}

func getCalories (name: String) async -> Double? {
    let url = URL(string: "https://trackapi.nutritionix.com/v2/natural/nutrients")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("7badc207", forHTTPHeaderField: "x-app-id")
    request.addValue("f98feb4aa6d0ba7d58389a229a993989", forHTTPHeaderField: "x-app-key")
    request.addValue("0", forHTTPHeaderField: "x-remote-user-id")
    guard let query = try? JSONEncoder().encode(NutrionixQuery(query: name)) else {
        return nil
    }
    do {
        let (data, response) = try await URLSession.shared.upload(for: request, from: query, delegate: nil)
        let decoder = JSONDecoder()
        do {
            let decodedValue = try decoder.decode(NutrionixResult.self, from: data)
            return decodedValue.foods[0].nf_calories
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }
    catch {
        print("Error")
        return nil
    }
}

// MARK: View

struct PhotosSelector: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var predictedType: ModelOutput?
    @State private var predictedCalories: Double?

    
    var body: some View {
        VStack (spacing: 50) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()) {
                    Text("Select a photo")
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        // Retrieve selected asset in the form of Data
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                        }
                    }
                }
            
            if let selectedImageData,
               let uiImage = UIImage(data: selectedImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)
            }
            Button {
                var apiString = "data:image/png;base64,"
                var combinedString = apiString + (UIImage(data: selectedImageData!)?.base64)!
                let image = ImageText(data: [combinedString])
                Task {
                    predictedType = try await mlPredict(image: image)
                    predictedCalories = try await getCalories(name: predictedType!.data[0].label)

                }
            } label: {
                Text("Analyze")
            }
            if predictedType != nil {
                Text(predictedType!.data[0].label)
            }
            if predictedCalories != nil {
                Text("\(predictedCalories!, specifier: "%.0f") Calories")
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack () {
            PhotosSelector()
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: Old Code with Callbacks
//    let task = URLSession.shared.uploadTask(with: request, from: data) { data, response, error in
//        if let error = error {
//            print ("error: \(error)")
//            return
//        }
//        guard let response = response as? HTTPURLResponse,
//              (200...299).contains(response.statusCode) else {
//            print ("server error")
//            return
//        }
//        if let mimeType = response.mimeType,
//           mimeType == "application/json",
//           let data = data,
//           let dataString = String(data: data, encoding: .utf8) {
//                print ("got data: \(dataString)")
//                let decoder = JSONDecoder()
//                do {
//                    let decodedValue = try decoder.decode(modelOutput.self, from: data)
//                    print("New: \(decodedValue)")
//                    predictedValue = decodedValue
//                } catch {
//                    print("Here \(error.localizedDescription)")
//                }
//            }
//    }
//    task.resume()
//    return predictedValue
