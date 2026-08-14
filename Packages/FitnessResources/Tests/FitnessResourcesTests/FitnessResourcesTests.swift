import Foundation
import Testing
@testable import FitnessResources

@Suite("App localization")
struct FitnessResourcesTests {
    @Test("Language identity and locales stay stable")
    func languageContract() {
        #expect(AppLanguage.english.rawValue == "en")
        #expect(AppLanguage.german.rawValue == "de")
        #expect(AppLanguage.english.locale.identifier == "en_US")
        #expect(AppLanguage.german.locale.identifier == "de_DE")
        #expect(AppLanguage.english.autonym == "English")
        #expect(AppLanguage.german.autonym == "Deutsch")
        #expect(AppLanguage.allCases.contains(.english))
        #expect(AppLanguage.allCases.contains(.german))
    }

    @Test("A new catalog localization becomes a language without another code case")
    func catalogDrivenLanguageExtension() {
        #expect(
            AppLanguage.languageCodes(in: ["Base", "en", "de", "fr"])
                == ["en", "de", "fr"]
        )
    }

    @Test("Live Activity language codes resolve with English compatibility fallback")
    func activityLanguageResolution() {
        #expect(AppLanguage.resolving(languageCode: "en") == .english)
        #expect(AppLanguage.resolving(languageCode: "de") == .german)
        #expect(AppLanguage.resolving(languageCode: nil) == .english)
        #expect(AppLanguage.resolving(languageCode: "unknown") == .english)
    }

    @Test("Catalog mappings resolve for both app locales")
    func languageMappings() {
        #expect(AppText.resolve(AppText.actionSave, locale: AppLanguage.english.locale) == "Save")
        #expect(AppText.resolve(AppText.actionSave, locale: AppLanguage.german.locale) == "Speichern")
    }

    @Test("Missing German translations fall back to the English default")
    func missingTranslationFallback() {
        let resource = LocalizedStringResource(
            "localization.missing_fixture",
            defaultValue: "English fallback",
            table: "Localizable",
            bundle: AppText.bundle
        )
        #expect(
            AppText.resolve(
                resource,
                locale: AppLanguage.german.locale
            ) == "English fallback"
        )
    }

    @Test("Interpolation resolves at render time in both languages")
    func interpolation() {
        #expect(AppText.resolve(AppText.profileGreeting(name: "Alex"), locale: AppLanguage.english.locale) == "Hey Alex")
        #expect(AppText.resolve(AppText.profileGreeting(name: "Alex"), locale: AppLanguage.german.locale) == "Hallo Alex")
    }

    @Test("Catalog plural variants resolve singular and plural")
    func plurals() {
        #expect(AppText.resolve(AppText.exerciseCount(count: 1), locale: AppLanguage.english.locale) == "1 exercise")
        #expect(AppText.resolve(AppText.exerciseCount(count: 2), locale: AppLanguage.english.locale) == "2 exercises")
        #expect(AppText.resolve(AppText.exerciseCount(count: 1), locale: AppLanguage.german.locale) == "1 Übung")
        #expect(AppText.resolve(AppText.exerciseCount(count: 2), locale: AppLanguage.german.locale) == "2 Übungen")
        #expect(AppText.resolve(AppText.analyticsPeriodDays(count: 1), locale: AppLanguage.english.locale) == "Period: 1 Day")
        #expect(AppText.resolve(AppText.analyticsPeriodDays(count: 2), locale: AppLanguage.german.locale) == "Zeitraum: 2 Tage")
        #expect(AppText.resolve(AppText.analyticsTrainingExercises(training: 1, exercises: 1), locale: AppLanguage.english.locale) == "1 Training · 1 Exercise")
        #expect(AppText.resolve(AppText.analyticsTrainingExercises(training: 2, exercises: 2), locale: AppLanguage.german.locale) == "2 Trainings · 2 Übungen")
        #expect(AppText.resolve(AppText.exerciseSetLabel(count: 1), locale: AppLanguage.english.locale) == "set")
        #expect(AppText.resolve(AppText.exerciseSetLabel(count: 2), locale: AppLanguage.german.locale) == "Sätze")
    }
}
