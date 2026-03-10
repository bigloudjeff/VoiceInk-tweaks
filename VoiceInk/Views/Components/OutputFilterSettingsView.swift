import SwiftUI

struct OutputFilterSettingsView: View {
 @AppStorage(UserDefaults.Keys.removeTagBlocks) private var removeTagBlocks = true
 @AppStorage(UserDefaults.Keys.removeBracketedContent) private var removeBracketedContent = true

 var body: some View {
  VStack(alignment: .leading, spacing: 10) {
   HStack {
    Toggle(isOn: $removeTagBlocks) {
     Text("Remove XML tag blocks")
    }
    .toggleStyle(.switch)

    InfoTip("Strip <TAG>...</TAG> blocks that some models produce as artifacts.")
   }

   HStack {
    Toggle(isOn: $removeBracketedContent) {
     Text("Remove bracketed content")
    }
    .toggleStyle(.switch)

    InfoTip("Strip content in [brackets], (parentheses), and {braces} that some models produce as hallucinations. Turn this off if your speech intentionally includes parenthetical remarks.")
   }
  }
 }
}
