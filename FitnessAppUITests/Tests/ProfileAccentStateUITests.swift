import XCTest

final class ProfileAccentStateUITests: BaseTest {
    @MainActor
    func testAccentSwitchKeepsExpandedProfileSectionsOpen() throws {
        try launchProfile()

        tapOn(ProfileIDs.bodyHeader)
        verifyExists(ProfileIDs.bmiRefresh)

        swipeUpUntilVisible(ProfileIDs.friendsHeader, elementType: .button)
        tapOn(ProfileIDs.friendsHeader)
        verifyExists(ProfileIDs.friendsUserRow)

        swipeDownUntilVisible(ProfileIDs.greyAccent, elementType: .button)
        tapOn(ProfileIDs.greyAccent)
        verifyValue(ProfileIDs.greyAccent, equals: "Selected", elementType: .button)
        verifyExists(ProfileIDs.bmiRefresh)
        verifyExists(ProfileIDs.friendsUserRow)

        tapOn(ProfileIDs.greenAccent)
        verifyValue(ProfileIDs.greenAccent, equals: "Selected", elementType: .button)
        verifyExists(ProfileIDs.bmiRefresh)
        verifyExists(ProfileIDs.friendsUserRow)
    }
}
