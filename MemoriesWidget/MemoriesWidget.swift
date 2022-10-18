//
//  MemoriesWidget.swift
//  MemoriesWidget
//
//  Created by Michael Brown on 18/10/2022.
//  Copyright © 2022 Michael Brown. All rights reserved.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), year: 2022)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), year: 2022)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, year: 2010 + hourOffset)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let year: Int
    var image: UIImage?
}

struct MemoriesWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            Color(.black)
            if let image = entry.image {
                Image(uiImage: image)
            } else {
                Image(systemName: "exclamationmark.triangle")
            }
            VStack {
                Spacer()
                Text(String(entry.year))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
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

struct MemoriesWidget_Previews: PreviewProvider {
    static var previews: some View {
        MemoriesWidgetEntryView(entry: SimpleEntry(date: Date(), year: 2022))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        MemoriesWidgetEntryView(entry: SimpleEntry(date: Date(), year: 2022))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        MemoriesWidgetEntryView(entry: SimpleEntry(date: Date(), year: 2022))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
