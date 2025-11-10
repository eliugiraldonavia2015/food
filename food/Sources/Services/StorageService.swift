//
//  StorageService.swift
//  food
//
//  Created by Gabriel Barzola arana on 10/11/25.
//

import Foundation
import FirebaseStorage
import UIKit

public final class StorageService {
    public static let shared = StorageService()
    private init() {}

    // Referencia raíz del bucket
    private let storage = Storage.storage()

    /// Sube la imagen de perfil y devuelve la URL de descarga
    public func uploadProfileImage(
        uid: String,
        image: UIImage,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Carpeta del usuario: users/{uid}/profile.jpg
        let path = "users/\(uid)/profile.jpg"
        let ref = storage.reference().child(path)

        // Comprimir (calidad 0.85 suele ser buen equilibrio)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            completion(.failure(NSError(domain: "StorageService",
                                        code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "No se pudo codificar la imagen a JPEG"])))
            return
        }

        // Metadata opcional
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Subir
        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            // Obtener URL descargable
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let url = url else {
                    completion(.failure(NSError(domain: "StorageService",
                                                code: -2,
                                                userInfo: [NSLocalizedDescriptionKey: "URL de descarga nula"])))
                    return
                }
                completion(.success(url))
            }
        }
    }
}
