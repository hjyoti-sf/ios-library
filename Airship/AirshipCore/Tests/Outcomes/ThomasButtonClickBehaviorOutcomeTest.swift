/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipCore

@Suite("Outcomes", .timeLimit(.minutes(1)))
struct ThomasButtonClickBehaviorOutcomeTest {

    // MARK: Pager navigation

    @Test
    func pagerNextMapsToStepNavigationNext() {
        guard case .pagerStepNavigation(let o) = ThomasButtonClickBehavior.pagerNext.asOutcome else {
            Issue.record("Expected .pagerStepNavigation")
            return
        }
        #expect(o.direction == .next)
        #expect(o.boundaryBehavior == .ignore)
    }

    @Test
    func pagerPreviousMapsToStepNavigationPrevious() {
        guard case .pagerStepNavigation(let o) = ThomasButtonClickBehavior.pagerPrevious.asOutcome else {
            Issue.record("Expected .pagerStepNavigation")
            return
        }
        #expect(o.direction == .previous)
        #expect(o.boundaryBehavior == .ignore)
    }

    @Test
    func pagerNextOrDismissMapsToStepNavigationWithDismissBoundary() {
        guard case .pagerStepNavigation(let o) = ThomasButtonClickBehavior.pagerNextOrDismiss.asOutcome else {
            Issue.record("Expected .pagerStepNavigation")
            return
        }
        #expect(o.direction == .next)
        #expect(o.boundaryBehavior == .dismiss)
    }

    @Test
    func pagerNextOrFirstMapsToStepNavigationWithWrapBoundary() {
        guard case .pagerStepNavigation(let o) = ThomasButtonClickBehavior.pagerNextOrFirst.asOutcome else {
            Issue.record("Expected .pagerStepNavigation")
            return
        }
        #expect(o.direction == .next)
        #expect(o.boundaryBehavior == .wrap)
    }

    // MARK: Pager playback

    @Test
    func pagerPauseMapsToPlaybackPause() {
        guard case .pagerPlayback(let o) = ThomasButtonClickBehavior.pagerPause.asOutcome else {
            Issue.record("Expected .pagerPlayback")
            return
        }
        #expect(o.command == .pause)
    }

    @Test
    func pagerResumeMapsToPlaybackResume() {
        guard case .pagerPlayback(let o) = ThomasButtonClickBehavior.pagerResume.asOutcome else {
            Issue.record("Expected .pagerPlayback")
            return
        }
        #expect(o.command == .resume)
    }

    @Test
    func pagerPauseToggleMapsToPlaybackToggle() {
        guard case .pagerPlayback(let o) = ThomasButtonClickBehavior.pagerPauseToggle.asOutcome else {
            Issue.record("Expected .pagerPlayback")
            return
        }
        #expect(o.command == .toggle)
    }

    // MARK: Media playback

    @Test
    func videoPlayMapsToMediaPlaybackPlay() {
        guard case .mediaPlayback(let o) = ThomasButtonClickBehavior.videoPlay.asOutcome else {
            Issue.record("Expected .mediaPlayback")
            return
        }
        #expect(o.command == .play)
    }

    @Test
    func videoPauseMapsToMediaPlaybackPause() {
        guard case .mediaPlayback(let o) = ThomasButtonClickBehavior.videoPause.asOutcome else {
            Issue.record("Expected .mediaPlayback")
            return
        }
        #expect(o.command == .pause)
    }

    @Test
    func videoTogglePlayMapsToMediaPlaybackToggle() {
        guard case .mediaPlayback(let o) = ThomasButtonClickBehavior.videoTogglePlay.asOutcome else {
            Issue.record("Expected .mediaPlayback")
            return
        }
        #expect(o.command == .toggle)
    }

    // MARK: Media audio

    @Test
    func videoMuteMapsToMediaAudioMute() {
        guard case .mediaAudio(let o) = ThomasButtonClickBehavior.videoMute.asOutcome else {
            Issue.record("Expected .mediaAudio")
            return
        }
        #expect(o.command == .mute)
    }

    @Test
    func videoUnmuteMapsToMediaAudioUnmute() {
        guard case .mediaAudio(let o) = ThomasButtonClickBehavior.videoUnmute.asOutcome else {
            Issue.record("Expected .mediaAudio")
            return
        }
        #expect(o.command == .unmute)
    }

    @Test
    func videoToggleMuteMapsToMediaAudioToggle() {
        guard case .mediaAudio(let o) = ThomasButtonClickBehavior.videoToggleMute.asOutcome else {
            Issue.record("Expected .mediaAudio")
            return
        }
        #expect(o.command == .toggle)
    }

    // MARK: Form

    @Test
    func formSubmitMapsToFormSubmit() {
        guard case .form(let o) = ThomasButtonClickBehavior.formSubmit.asOutcome else {
            Issue.record("Expected .form")
            return
        }
        #expect(o.command == .submit)
    }

    @Test
    func formValidateMapsToFormValidate() {
        guard case .form(let o) = ThomasButtonClickBehavior.formValidate.asOutcome else {
            Issue.record("Expected .form")
            return
        }
        #expect(o.command == .validate)
    }

    // MARK: Dismiss

    @Test
    func dismissMapsToNonCancelDismiss() {
        guard case .dismiss(let o) = ThomasButtonClickBehavior.dismiss.asOutcome else {
            Issue.record("Expected .dismiss")
            return
        }
        #expect(o.cancel == false)
    }

    @Test
    func cancelMapsToCancelDismiss() {
        guard case .dismiss(let o) = ThomasButtonClickBehavior.cancel.asOutcome else {
            Issue.record("Expected .dismiss")
            return
        }
        #expect(o.cancel == true)
    }

    // MARK: Async view

    @Test
    func asyncViewRetryMapsToAsyncViewRetry() {
        guard case .asyncView(let o) = ThomasButtonClickBehavior.asyncViewRetry.asOutcome else {
            Issue.record("Expected .asyncView")
            return
        }
        #expect(o.command == .retry)
    }

    // MARK: Exhaustiveness

    @Test("Every behavior produces a non-nil outcome", arguments: ThomasButtonClickBehaviorParsingTest.allBehaviors)
    func everyBehaviorProducesAnOutcome(behavior: ThomasButtonClickBehavior) {
        // Calling .asOutcome must not crash; the switch is exhaustive by construction,
        // so this test acts as a compile-time + runtime exhaustiveness guard.
        _ = behavior.asOutcome
    }
}
