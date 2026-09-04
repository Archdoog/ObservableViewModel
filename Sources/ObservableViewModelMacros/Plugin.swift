import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ObservableViewModelPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ObservableViewModelMacro.self,
    ]
}
