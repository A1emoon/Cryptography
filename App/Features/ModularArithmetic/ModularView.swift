import SwiftUI
struct ModularView:View {var isDivision=false;var body:some View{CourseTaskView(kind:isDivision ? .modularDivision : .inverse)}}
