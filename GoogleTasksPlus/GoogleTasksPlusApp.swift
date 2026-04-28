import SwiftUI

@main
struct GoogleTasksPlusApp: App {
    @StateObject private var authService = GoogleAuthService()
    @StateObject private var tasksService = GoogleTasksService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(tasksService)
                .frame(minWidth: 480, idealWidth: 600, minHeight: 600, idealHeight: 800)
                .task {
                    if authService.isAuthenticated {
                        tasksService.startObserving(authService: authService)
                    }
                }
                .onChange(of: authService.isAuthenticated) { _, isAuth in
                    if isAuth {
                        tasksService.startObserving(authService: authService)
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 600, height: 800)
    }
}
