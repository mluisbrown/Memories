//
//  MemoriesWidget.swift
//  MemoriesWidget
//
//  Created by Michael Brown on 18/10/2022.
//  Copyright © 2022 Michael Brown. All rights reserved.
//

import WidgetKit
import SwiftUI
import Photos
import PHAssetHelper

struct Provider: TimelineProvider {
    private let cacheSize = CGSize(width: 256, height: 256)
    private let requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        return options
    }()
    private let imageManager = PHCachingImageManager()

    func placeholder(in context: Context) -> ImageEntry {
        ImageEntry(date: Date(), year: 2022)
    }

    func getSnapshot(in context: Context, completion: @escaping (ImageEntry) -> ()) {
        Task {
            let entries = await getTimelineEntries()
            guard let entry = entries.first else {
                completion(ImageEntry(date: Date(), year: 2022))
                return
            }

            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let entries = await getTimelineEntries()
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    func getTimelineEntries() async -> [ImageEntry] {
#if targetEnvironment(simulator)
        let date = Calendar(identifier: Calendar.Identifier.gregorian).date(from: DateComponents(era: 1, year: 2016, month: 8, day: 8, hour: 0, minute: 0, second: 0, nanosecond: 0))!
#else
        let date = Date()
#endif

        let assets = await withCheckedContinuation { continuation in
            let assets = PHAssetHelper().allAssetsForAllYears(with: date)
            continuation.resume(returning: assets)
        }.shuffled()

        let timelineAssets: [PHAsset]
        let favAssets = assets.filter(\.isFavorite)

        if favAssets.count < 5 {
            let otherAssets = Array(
                assets.filter { $0.isFavorite == false }
                    .prefix(5 - favAssets.count)
            )
            timelineAssets = [favAssets, otherAssets].flatMap { $0 }
        } else {
            timelineAssets = favAssets
        }

        var entries: [ImageEntry] = []
        for (index, asset) in timelineAssets.enumerated() {
            let image = await loadImage(for: asset)
            let date = Calendar.current.date(byAdding: .hour, value: index, to: Date())!
            entries.append(
                ImageEntry(
                    date: date,
                    year: asset.creationDate?.year ?? Date().year,
                    image: image
                )
            )
        }

        return entries
    }

    func loadImage(for asset: PHAsset) async -> UIImage {
        await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: cacheSize,
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, userInfo in
                if let image {
                    let isDegraded = ((userInfo?[PHImageResultIsDegradedKey] as? NSNumber) as? Bool) ?? true
                    if !isDegraded {
                        continuation.resume(returning: image)
                    }
                }
            }
        }
    }
}

struct ImageEntry: TimelineEntry {
    let date: Date
    let year: Int
    var image: UIImage?
}

struct MemoriesWidgetEntryView : View {

    var entry: Provider.Entry

    var yearFont: UIFont {
        if #available(iOS 16, *) {
            return UIFont.systemFont(ofSize: 15, weight: .bold, width: .expanded)
        } else {
            return UIFont.systemFont(ofSize: 15, weight: .bold)
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.black)
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                }
                Text(String(entry.year))
                    .font(Font(yearFont))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(x: 0, y: -8)
            }
        }
    }
}

@main
struct MemoriesWidget: Widget {
    let kind: String = "MemoriesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MemoriesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Photos from this day")
        .description("Photos from this day over the years")
    }
}

extension UIColor {
    func image(_ size: CGSize = CGSize(width: 256, height: 256)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}

struct MemoriesWidget_Previews: PreviewProvider {
    static var previews: some View {
        MemoriesWidgetEntryView(entry: ImageEntry(date: Date(), year: 2022, image: UIColor.red.image()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        MemoriesWidgetEntryView(entry: ImageEntry(date: Date(), year: 2022, image: UIColor.red.image()))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        MemoriesWidgetEntryView(entry: ImageEntry(date: Date(), year: 2022, image: UIColor.red.image()))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
