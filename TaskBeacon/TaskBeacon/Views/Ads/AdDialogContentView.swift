//
//  Copyright 2022 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SwiftUI

struct AdDialogContentView: View {
    @StateObject private var countdownTimer = CountdownTimer(5)
    
    @Binding var isPresenting: Bool
    @Binding var countdownComplete: Bool
    
    var onSkip: (() -> Void)?

    var body: some View {
        ZStack {
            Color.clear
                .opacity(0.75)
                .ignoresSafeArea(.all)

            VStack {
                Spacer()
                
                dialogBody
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 24)
                
                Spacer()
            }
//            dialogBody
//                .background(Color.white)
//                .padding()
        }
    }

    var dialogBody: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Watch Ad for an Extra To-Do or Shopping Item")
                .font(.headline)

            Text("Video starting in \(countdownTimer.timeLeft)...")
                .foregroundColor(.gray)

            HStack {
                Spacer()
                Button {
                    isPresenting = false
                    
                    onSkip?()
                } label: {
                    Text("Skip")
                        .bold()
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            countdownComplete = false
            countdownTimer.start()
        }
        .onDisappear {
            countdownTimer.pause()
        }
        .onChange(of: isPresenting) {
            isPresenting ? countdownTimer.start() : countdownTimer.pause()
        }
        .onChange(of: countdownTimer.isComplete) {
            if countdownTimer.isComplete {
                countdownComplete = true
                isPresenting = false
            }
        }
        .padding()
    }
}

struct AdDialogContentView_Previews: PreviewProvider {
  static var previews: some View {
    AdDialogContentView(isPresenting: .constant(true), countdownComplete: .constant(false))
  }
}
