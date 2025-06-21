//
//  OnboardingView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 6/21/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var showHelpView = false
    @State private var currentStep = 0
    @State private var currentIndex = 0
    
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
    
    let icons = [
        (systemName: "cart", title: "Shopping List", color: Color(hex: "FFD300")),
        (systemName: "checklist", title: "To-Do List", color: Color(hex: "005D5D")),
        (systemName: "mappin.and.ellipse", title: "Location-Based Reminders", color: Color(hex: "1240AB"))
    ]

    let onboardingSteps = [
        OnboardingStep(
            title: "Welcome to TaskBeacon",
            subtitle: "Your smart shopping and task companion",
            description: "Organize shopping lists and to-do items with location-based reminders.",
            showAnimatedIcons: true
        ),
        OnboardingStep(
            title: "Shopping Lists",
            subtitle: "Never forget what to buy",
            description: "Add items, assign stores, and get notified when you're nearby.",
            showAnimatedIcons: false,
            icon: "cart.fill",
            iconColor: Color(hex: "FFD300")
        ),
        OnboardingStep(
            title: "To-Do Lists",
            subtitle: "Stay organized and productive",
            description: "Create tasks with priorities, due dates, and location reminders.",
            showAnimatedIcons: false,
            icon: "checklist",
            iconColor: Color(hex: "005D5D")
        ),
        OnboardingStep(
            title: "Location Reminders",
            subtitle: "Smart notifications",
            description: "Get reminded when you're near stores or task locations.",
            showAnimatedIcons: false,
            icon: "mappin.and.ellipse",
            iconColor: Color(hex: "1240AB")
        )
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Onboarding content
            TabView(selection: $currentStep) {
                ForEach(0..<onboardingSteps.count, id: \.self) { index in
                    OnboardingStepView(
                        step: onboardingSteps[index],
                        currentIndex: currentIndex,
                        icons: icons
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .onReceive(timer) { _ in
                // Only auto-cycle on the first step (welcome screen)
                if currentStep == 0 {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentIndex = (currentIndex + 1) % icons.count
                    }
                }
            }
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Previous") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                }
                
                Spacer()
                
                if currentStep < onboardingSteps.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            
            // Learn More button on last step
            if currentStep == onboardingSteps.count - 1 {
                Button(action: {
                    showHelpView = true
                }) {
                    Text("Learn More About TaskBeacon")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showHelpView) {
            HelperView()
        }
    }
}

struct OnboardingStep {
    let title: String
    let subtitle: String
    let description: String
    let showAnimatedIcons: Bool
    let icon: String?
    let iconColor: Color?
    
    init(title: String,
         subtitle: String,
         description: String,
         showAnimatedIcons: Bool = false,
         icon: String? = nil,
         iconColor: Color? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.showAnimatedIcons = showAnimatedIcons
        self.icon = icon
        self.iconColor = iconColor
    }
}

struct OnboardingStepView: View {
    let step: OnboardingStep
    let currentIndex: Int
    let icons: [(systemName: String, title: String, color: Color)]
    
    var body: some View {
        VStack(spacing: 30) {
            if step.showAnimatedIcons {
                // Animated icons for welcome screen
                VStack(spacing: 20) {
                    Image(systemName: icons[currentIndex].systemName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(icons[currentIndex].color)
                        .transition(.scale.combined(with: .opacity))
                    
                    Text(icons[currentIndex].title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.5), value: currentIndex)
            } else {
                // Static icon for other steps
                if let icon = step.icon, let iconColor = step.iconColor {
                    Image(systemName: icon)
                        .font(.system(size: 80))
                        .foregroundColor(iconColor)
                }
            }
            
            VStack(spacing: 10) {
                Text(step.title)
                    .font(.title)
                    .bold()
                
                Text(step.subtitle)
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text(step.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

//#Preview {
//    OnboardingView()
//}
