//
//  ContentView.swift
//  calorie-tracker
//
//  Created by David Patterson-Cole on 2022-12-09.
//

import SwiftUI
import PhotosUI

struct Course: Hashable, Codable {
    let name: String
    let image: String
}

class ViewModel: ObservableObject {
    @Published var courses: [Course] = []
    
    func fetch() {
        guard let url = URL(string: "https://iosacademy.io/api/v1/courses/index.php") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _,
            error in
            guard let data = data, error == nil else {
                return
            }
            // convert to JSON
            do {
                let courses = try JSONDecoder().decode([Course].self, from: data)
                DispatchQueue.main.async {
                    self?.courses = courses
                }
            } catch {
                print(error)
            }
        }
        task.resume()
    }
}

struct testAPI: View {
    
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.courses, id: \.self) { course in
                    HStack {
                        Image("")
                            .frame(width: 130, height: 70)
                            .background(Color.gray)
                        Text(course.name)
                            .bold()
                    }
                }
                
            }
            .navigationTitle("Courses")
            .onAppear {
                viewModel.fetch()
            }
        }
    }
}

struct ImageText: Codable {
    let data: [String]
}

extension UIImage {
    var base64: String? {
        self.jpegData(compressionQuality: 1)?.base64EncodedString()
    }
}

struct PhotosSelector: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
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
                print("test")
                var apiString = "data:image/png;base64,"
                var combinedString = apiString + (UIImage(data: selectedImageData!)?.base64)!
                let image = ImageText(data: [combinedString])
                
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted

                guard let data = try? encoder.encode(image) else {
                    return
                }
                print("Encoded: \(String(data: data, encoding: .utf8)!)")
                
//                guard let data = try? JSONEncoder().encode(image) else {
//                    return
//                }
                
//                print("uploadImage: \(image)")
                print("uploadImage: \(data)")
                
                let url = URL(string: "https://dpc7-pet-test.hf.space/run/predict")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let task = URLSession.shared.uploadTask(with: request, from: data) { data, response, error in
                    if let error = error {
                        print ("error: \(error)")
                        return
                    }
                    guard let response = response as? HTTPURLResponse,
                        (200...299).contains(response.statusCode) else {
                        print ("server error")
                        return
                    }
                    if let mimeType = response.mimeType,
                        mimeType == "application/json",
                        let data = data,
                        let dataString = String(data: data, encoding: .utf8) {
                        print ("got data: \(dataString)")
                    }
                }
                task.resume()
            } label: {
                Text("Upload")
            }
        }
    }
}

struct ContentView: View {
    
    @State private var selectedItem: PhotosPickerItem? = nil

    
    var body: some View {
        VStack () {
//            testAPI()
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
