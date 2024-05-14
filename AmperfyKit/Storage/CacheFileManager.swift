//
//  CacheFileManager.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 24.04.24.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

public class CacheFileManager {
    
    private static var inst: CacheFileManager?
    public static var shared: CacheFileManager {
        if inst == nil { inst = CacheFileManager() }
        return inst!
    }
    
    private let fileManager = FileManager.default

    public func moveItemToTempDirectoryWithUniqueName(at: URL) throws -> URL {
        // Get the URL to the app container's 'tmp' directory.
        var tmpFileURL = fileManager.temporaryDirectory
        tmpFileURL.appendPathComponent(UUID().uuidString, isDirectory: false)
        try fileManager.moveItem(at: at, to: tmpFileURL)
        return tmpFileURL
    }
    
    public func moveExcludedFromBackupItem(at: URL, to: URL) throws {
        let subDir = to.deletingLastPathComponent()
        if createDirectoryIfNeeded(at: subDir) {
            try? markItemAsExcludedFromBackup(at: subDir)
        }
        try fileManager.moveItem(at: at, to: to)
        try markItemAsExcludedFromBackup(at: to)
    }
    
    @discardableResult
    public func createDirectoryIfNeeded(at url: URL) -> Bool {
        guard !fileManager.fileExists(atPath: url.path) else { return false }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
        return true
    }
    
    public func removeItem(at: URL) throws {
        try fileManager.removeItem(at: at)
    }
    
    private func getOrCreateAmperfyDirectory() -> URL?  {
        var amperfyDir: URL? = nil
        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           // Get the URL to the app container's 'Library' directory.
           var url = try? fileManager.url(for: .libraryDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: false)
        {
            // Append the bundle identifier to the retrieved URL.
            url.appendPathComponent(bundleIdentifier, isDirectory: true)
            if createDirectoryIfNeeded(at: url) {
                try? markItemAsExcludedFromBackup(at: url)
            }
            amperfyDir = url
        }
        return amperfyDir
    }
        
    private func getOrCreateSubDirectory(subDirectoryName: String) -> URL?  {
        guard let url = getOrCreateAmperfyDirectory()?.appendingPathComponent(subDirectoryName, isDirectory: true) else { return nil }
        if createDirectoryIfNeeded(at: url) {
            try? markItemAsExcludedFromBackup(at: url)
        }
        return url
    }
    
    public func deletePlayableCache() {
        if let absSongsDir = getAbsoluteAmperfyPath(relFilePath: Self.songsDir) {
            try? fileManager.removeItem(at: absSongsDir)
        }
        if let absEpisodesDir = getAbsoluteAmperfyPath(relFilePath: Self.episodesDir) {
            try? fileManager.removeItem(at: absEpisodesDir)
        }
        if let absEmbeddedArtworksDir = getAbsoluteAmperfyPath(relFilePath: Self.embeddedArtworksDir) {
            try? fileManager.removeItem(at: absEmbeddedArtworksDir)
        }
    }
    
    public var playableCacheSize: Int64 {
        var bytes = Int64(0)
        if let absSongsDir = getAbsoluteAmperfyPath(relFilePath: Self.songsDir) {
            bytes += directorySize(url: absSongsDir)
        }
        if let absEpisodesDir = getAbsoluteAmperfyPath(relFilePath: Self.episodesDir) {
            bytes += directorySize(url: absEpisodesDir)
        }
        return bytes
    }
    
    private static let songsDir = URL(string: "songs")!
    private static let episodesDir = URL(string: "episodes")!
    private static let artworksDir = URL(string: "artworks")!
    private static let embeddedArtworksDir = URL(string: "embedded-artworks")!
    
    public func getOrCreateAbsoluteSongsDirectory() -> URL?  {
        return getOrCreateSubDirectory(subDirectoryName: Self.songsDir.path)
    }
    
    public func getOrCreateAbsolutePodcastEpisodesDirectory() -> URL?  {
        return getOrCreateSubDirectory(subDirectoryName: Self.episodesDir.path)
    }
    
    public func getOrCreateAbsoluteArtworksDirectory() -> URL?  {
        return getOrCreateSubDirectory(subDirectoryName: Self.artworksDir.path)
    }
    
    public func getOrCreateAbsoluteEmbeddedArtworksDirectory() -> URL?  {
        return getOrCreateSubDirectory(subDirectoryName: Self.embeddedArtworksDir.path)
    }
    
    public func createRelPath(for playable: AbstractPlayable) -> URL? {
        guard !playable.playableManagedObject.id.isEmpty else { return nil }
        if playable.isSong {
            return Self.songsDir.appendingPathComponent(playable.playableManagedObject.id)
        } else {
            return Self.episodesDir.appendingPathComponent(playable.playableManagedObject.id)
        }
    }
    
    public func createRelPath(for artwork: Artwork) -> URL? {
        guard !artwork.managedObject.id.isEmpty else { return nil }
        return Self.artworksDir.appendingPathComponent(artwork.managedObject.id)
    }
    
    public func createRelPath(for embeddedArtwork: EmbeddedArtwork) -> URL? {
        guard let owner = embeddedArtwork.owner,
              let ownerRelFilePath = createRelPath(for: owner)
        else { return nil }
        return Self.embeddedArtworksDir.appendingPathComponent(ownerRelFilePath.path)
    }
    
    public func getAmperfyPath() -> String? {
        return getOrCreateAmperfyDirectory()?.path
    }
    
    public func getAbsoluteAmperfyPath(relFilePath: URL) -> URL? {
        guard let amperfyDir = getOrCreateAmperfyDirectory() else { return nil }
        return amperfyDir.appendingPathComponent(relFilePath.path)
    }
    
    public func fileExits(relFilePath: URL) -> Bool {
        guard let absFilePath = getOrCreateAmperfyDirectory()?.appendingPathComponent(relFilePath.path) else { return false }
        return fileManager.fileExists(atPath: absFilePath.path)
    }
    
    public func writeDataExcludedFromBackup(data: Data, to: URL) throws {
        let subDir = to.deletingLastPathComponent()
        if createDirectoryIfNeeded(at: subDir) {
            try? markItemAsExcludedFromBackup(at: subDir)
        }
        try data.write(to: to, options: [.atomic])
        try markItemAsExcludedFromBackup(at: to)
    }
    
    public func markItemAsExcludedFromBackup(at: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        // Apply those values to the URL.
        var url = at
        try url.setResourceValues(values)
    }
    
    public func directorySize(url: URL) -> Int64 {
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
        } catch {
            return 0
        }

        var size: Int64 = 0

        for url in contents {
            let isDirectoryResourceValue: URLResourceValues
            do {
                isDirectoryResourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
            } catch {
                continue
            }
        
            if isDirectoryResourceValue.isDirectory == true {
                size += directorySize(url: url)
            } else {
                let fileSizeResourceValue: URLResourceValues
                do {
                    fileSizeResourceValue = try url.resourceValues(forKeys: [.fileSizeKey])
                } catch {
                    continue
                }
            
                size += Int64(fileSizeResourceValue.fileSize ?? 0)
            }
        }
        return size
    }
    
}
