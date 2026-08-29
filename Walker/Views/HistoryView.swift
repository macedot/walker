import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \RunRecord.date, order: .reverse)
    private var records: [RunRecord]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.walkerBg.ignoresSafeArea()
                if records.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("History")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "skull")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No runs yet")
                .font(.headline)
            Text("Outrun the horde and your runs will show up here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var list: some View {
        List {
            ForEach(records) { record in
                RunRow(record: record)
                    .listRowBackground(Color.walkerPanel)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct RunRow: View {
    let record: RunRecord

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: record.survived ? "figure.run" : "skull.fill")
                .font(.title3)
                .foregroundStyle(record.survived ? .toxicGreen : .bloodRed)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.date, style: .date)
                    .font(.subheadline.weight(.semibold))
                Text("\(record.difficulty.label) · \(record.survived ? "Survived" : "Caught")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Format.duration(record.duration))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                HStack(spacing: 8) {
                    Text(Format.distance(record.distanceMeters))
                    Label("\(record.kills)", systemImage: "scope")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .panel()
    }
}
