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

extension Date {
    var year: Int {
        Calendar(identifier: .gregorian).dateComponents([.year], from: self).year!
    }
}

struct Provider: TimelineProvider {
    private let previewOptions = PHImageRequestOptions().with {
        $0.isNetworkAccessAllowed = false
        $0.deliveryMode = .opportunistic
        $0.isSynchronous = false
    }

    private let highQualityOptions = PHImageRequestOptions().with {
        $0.isNetworkAccessAllowed = true
        $0.deliveryMode = .highQualityFormat
        $0.isSynchronous = false
    }

    private let imageManager = PHImageManager.default()

    func placeholder(in context: Context) -> ImageEntry {
        ImageEntry(date: Date(), imageDate: Date(), image: UIImage(named: "sample")!)
    }

    func getSnapshot(in context: Context, completion: @escaping (ImageEntry) -> ()) {
        Task {
            let entries = await getTimelineEntries(in: context, isSnapshot: true)
            guard let entry = entries.first else {
                completion(ImageEntry(date: Date(), imageDate: Date(), image: UIImage(named: "sample")!))
                return
            }

            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let entries = await getTimelineEntries(in: context)
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }
}

extension Provider {
    func getTimelineEntries(in context: Context, isSnapshot: Bool = false) async -> [ImageEntry] {
#if targetEnvironment(simulator)
        let date = Calendar(identifier: Calendar.Identifier.gregorian)
                .date(from: DateComponents(era: 1, year: 2016, month: 8, day: 8, hour: 0, minute: 0, second: 0, nanosecond: 0))!
#else
        let date = Date()
#endif

        let assets = await withCheckedContinuation { continuation in
            let assets = PHAssetHelper().allAssetsForAllYears(with: date)
            continuation.resume(returning: assets)
        }.shuffled()

        var timelineAssets: [PHAsset]
        let favAssets = assets.filter(\.isFavorite)

        if favAssets.count < 5 {
            let otherAssets = Array(
                assets.filter { $0.isFavorite == false }
                    .prefix(5 - favAssets.count)
                    .sorted {
                        if #available(iOSApplicationExtension 15, *) {
                            return $0.hasAdjustments && $1.hasAdjustments == false
                        } else {
                            return true
                        }
                    }
            )
            timelineAssets = [favAssets, otherAssets].flatMap { $0 }
        } else {
            timelineAssets = favAssets
        }

        if isSnapshot && context.isPreview {
            timelineAssets = timelineAssets.first.map(Array.init) ?? []
        }

        var entries: [ImageEntry] = []
        for (index, asset) in timelineAssets.enumerated() {
            let image = await loadImage(for: asset, isPreview: context.isPreview)
            let date = Calendar.current.date(byAdding: .hour, value: index, to: Date())!
            entries.append(
                ImageEntry(
                    date: date,
                    imageDate: asset.creationDate ?? Date(),
                    image: image
                )
            )
        }

        return entries
    }

    func loadImage(for asset: PHAsset, isPreview: Bool) async -> UIImage {
        let size: CGSize
        let options: PHImageRequestOptions

        if isPreview {
            size = CGSize(width: 256, height: 256)
            options = previewOptions
        } else {
            size = CGSize(width: 512, height: 512)
            options = highQualityOptions
        }

        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
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
    let imageDate: Date
    let image: UIImage
}

struct MemoriesWidgetEntryView : View {
    var entry: Provider.Entry

    var deepLinkURL: URL {
        let dateFormatter = DateFormatter().with {
            $0.dateFormat = "yyyyMMdd"
            $0.timeZone = TimeZone(secondsFromGMT: 0)
        }

        let dateString = dateFormatter.string(from: entry.imageDate)
        return URL(string: "memories://\(dateString)")!
    }

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

                Image(uiImage: entry.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .unredacted()

                Text(String(entry.imageDate.year))
                    .font(Font(yearFont))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(x: 0, y: -8)
                    .unredacted()
            }
        }
        .widgetURL(deepLinkURL)
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

struct MemoriesWidget_Previews: PreviewProvider {
    static var previews: some View {
        MemoriesWidgetEntryView(entry: ImageEntry(date: Date(), imageDate: Date(), image: UIImage(named: "sample")!))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        MemoriesWidgetEntryView(entry: ImageEntry(date: Date(), imageDate: Date(), image: UIImage(named: "sample")!))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        MemoriesWidgetEntryView(entry: ImageEntry(date: Date(), imageDate: Date(), image: UIImage(named: "sample")!))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
