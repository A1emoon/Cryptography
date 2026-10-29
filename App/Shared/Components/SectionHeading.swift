import SwiftUI

struct SectionHeading: View {
    let number: String
    let title: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(number).font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(AppStyle.accent)
            Text(title).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
        }
    }
}

