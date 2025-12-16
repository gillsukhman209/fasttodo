import Foundation

// MARK: - Parsed Output

struct ParsedInput {
    let title: String
    let scheduledDate: Date?
    let hasSpecificTime: Bool
    let recurrenceRule: RecurrenceRule?
}

// MARK: - Natural Language Parser

final class NaturalLanguageParser {

    // MARK: - Dependencies

    private let dateDetector: NSDataDetector?
    private let calendar: Calendar

    // MARK: - Init

    init() {
        self.dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        self.calendar = Calendar.current
    }

    // MARK: - Main Parse Method

    func parse(_ input: String) -> ParsedInput {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return ParsedInput(title: "", scheduledDate: nil, hasSpecificTime: false, recurrenceRule: nil)
        }

        // Step 1: Extract recurrence first
        let (inputAfterRecurrence, recurrence) = extractRecurrence(from: trimmed)

        // Step 2: Extract date/time
        let (inputAfterDate, date, hasTime) = extractDateTime(from: inputAfterRecurrence)

        // Step 3: Clean up title
        let cleanedTitle = cleanTitle(inputAfterDate)

        // Step 4: If recurrence but no date, set to next occurrence
        var finalDate = date
        if recurrence != nil && date == nil {
            finalDate = recurrence?.nextOccurrence(after: Date())
        }

        return ParsedInput(
            title: cleanedTitle,
            scheduledDate: finalDate,
            hasSpecificTime: hasTime,
            recurrenceRule: recurrence
        )
    }

    // MARK: - Recurrence Extraction

    private static let recurrencePatterns: [(pattern: String, rule: RecurrenceRule)] = [
        // Daily
        ("every day", .daily),
        ("everyday", .daily),
        ("daily", .daily),

        // Weekdays/Weekends
        ("every weekday", .weekdays),
        ("weekdays", .weekdays),
        ("every weekend", .weekends),
        ("weekends", .weekends),

        // Weekly
        ("every week", .weekly),
        ("weekly", .weekly),
        ("biweekly", .biweekly),
        ("bi-weekly", .biweekly),

        // Monthly/Yearly
        ("every month", .monthly),
        ("monthly", .monthly),
        ("every year", .yearly),
        ("yearly", .yearly),
        ("annually", .yearly),

        // Specific days
        ("every monday", .every(2)),
        ("every tuesday", .every(3)),
        ("every wednesday", .every(4)),
        ("every thursday", .every(5)),
        ("every friday", .every(6)),
        ("every saturday", .every(7)),
        ("every sunday", .every(1)),

        // Short forms
        ("every mon", .every(2)),
        ("every tue", .every(3)),
        ("every wed", .every(4)),
        ("every thu", .every(5)),
        ("every fri", .every(6)),
        ("every sat", .every(7)),
        ("every sun", .every(1)),
    ]

    private func extractRecurrence(from input: String) -> (String, RecurrenceRule?) {
        let lowercased = input.lowercased()

        for (pattern, rule) in Self.recurrencePatterns {
            if lowercased.contains(pattern) {
                let cleaned = input.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: [.caseInsensitive]
                )
                return (cleaned, rule)
            }
        }

        return (input, nil)
    }

    // MARK: - Date/Time Extraction

    private static let relativePatterns: [(pattern: String, resolver: (Calendar) -> (Date?, Bool))] = [
        ("tonight", { cal in
            (cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date()), true)
        }),
        ("this evening", { cal in
            (cal.date(bySettingHour: 18, minute: 0, second: 0, of: Date()), true)
        }),
        ("this afternoon", { cal in
            (cal.date(bySettingHour: 14, minute: 0, second: 0, of: Date()), true)
        }),
        ("this morning", { cal in
            (cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date()), true)
        }),
        ("tomorrow morning", { cal in
            let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            return (cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow), true)
        }),
        ("tomorrow evening", { cal in
            let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            return (cal.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow), true)
        }),
        ("tomorrow night", { cal in
            let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            return (cal.date(bySettingHour: 20, minute: 0, second: 0, of: tomorrow), true)
        }),
        ("tomorrow", { cal in
            (cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())), false)
        }),
        ("today", { cal in
            (cal.startOfDay(for: Date()), false)
        }),
        ("next week", { cal in
            (cal.date(byAdding: .weekOfYear, value: 1, to: Date()), false)
        }),
        ("next month", { cal in
            (cal.date(byAdding: .month, value: 1, to: Date()), false)
        }),
    ]

    private func extractDateTime(from input: String) -> (String, Date?, Bool) {
        var workingInput = input
        var foundDate: Date?
        var hasSpecificTime = false

        let lowercased = input.lowercased()

        // Check relative patterns first
        for (pattern, resolver) in Self.relativePatterns {
            if lowercased.contains(pattern) {
                let (date, hasTime) = resolver(calendar)
                foundDate = date
                hasSpecificTime = hasTime
                workingInput = input.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: [.caseInsensitive]
                )
                break
            }
        }

        // Use NSDataDetector for complex expressions
        if let detector = dateDetector {
            let range = NSRange(workingInput.startIndex..., in: workingInput)
            let matches = detector.matches(in: workingInput, options: [], range: range)

            if let match = matches.first, let date = match.date {
                // Check if time is included
                if let matchRange = Range(match.range, in: workingInput) {
                    let matchedText = String(workingInput[matchRange]).lowercased()
                    let timeIndicators = ["am", "pm", ":", "o'clock", "noon", "midnight"]
                    let containsTime = timeIndicators.contains { matchedText.contains($0) }

                    if containsTime {
                        hasSpecificTime = true
                    }

                    // Combine dates if needed
                    if let existingDate = foundDate, containsTime {
                        // Use existing date but with detected time
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
                        foundDate = calendar.date(
                            bySettingHour: timeComponents.hour ?? 0,
                            minute: timeComponents.minute ?? 0,
                            second: 0,
                            of: existingDate
                        )
                    } else if foundDate == nil {
                        foundDate = date
                        hasSpecificTime = containsTime
                    }

                    // Remove matched text
                    workingInput.removeSubrange(matchRange)
                }
            }
        }

        // Check for standalone time patterns like "at 7pm", "at 3:30"
        let timePattern = #"(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)"#
        if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive) {
            let range = NSRange(workingInput.startIndex..., in: workingInput)
            if let match = regex.firstMatch(in: workingInput, options: [], range: range) {
                if let hourRange = Range(match.range(at: 1), in: workingInput) {
                    var hour = Int(workingInput[hourRange]) ?? 0
                    var minute = 0

                    if let minuteRange = Range(match.range(at: 2), in: workingInput) {
                        minute = Int(workingInput[minuteRange]) ?? 0
                    }

                    if let ampmRange = Range(match.range(at: 3), in: workingInput) {
                        let ampm = workingInput[ampmRange].lowercased()
                        if ampm.contains("p") && hour < 12 {
                            hour += 12
                        } else if ampm.contains("a") && hour == 12 {
                            hour = 0
                        }
                    }

                    let baseDate = foundDate ?? Date()
                    foundDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
                    hasSpecificTime = true

                    if let fullRange = Range(match.range, in: workingInput) {
                        workingInput.removeSubrange(fullRange)
                    }
                }
            }
        }

        return (workingInput, foundDate, hasSpecificTime)
    }

    // MARK: - Title Cleaning

    private func cleanTitle(_ input: String) -> String {
        var cleaned = input

        // Remove common preposition artifacts
        let artifacts = ["at", "on", "by", "for", "the", "in"]
        for artifact in artifacts {
            // Remove if at start
            let startPattern = "^\\s*\(artifact)\\s+"
            if let regex = try? NSRegularExpression(pattern: startPattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }

            // Remove if at end
            let endPattern = "\\s+\(artifact)\\s*$"
            if let regex = try? NSRegularExpression(pattern: endPattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }

        // Collapse multiple spaces
        cleaned = cleaned
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize first letter
        if let first = cleaned.first {
            cleaned = first.uppercased() + cleaned.dropFirst()
        }

        return cleaned
    }
}
