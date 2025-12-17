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

        // Step 0: Handle "remind" shortcut - strip it and parse the rest
        let processedInput = stripRemindPrefix(from: trimmed)

        // Step 1: Extract recurrence first
        let (inputAfterRecurrence, recurrence) = extractRecurrence(from: processedInput)

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

    // MARK: - Remind Prefix Handling

    private func stripRemindPrefix(from input: String) -> String {
        var result = input

        // Order matters - check longer patterns first
        // Don't strip "in" - it's part of the time expression like "in 5 mins"
        let remindPrefixes = [
            "^remind\\s+me\\s+to\\s+",      // "remind me to call mom"
            "^remind\\s+me\\s+",            // "remind me call mom" or "remind me in 5 mins..."
            "^reminder\\s+to\\s+",          // "reminder to call mom"
            "^reminder\\s+",                // "reminder call mom"
            "^remind\\s+",                  // "remind call mom in 2 mins" (shortcut!)
        ]

        for pattern in remindPrefixes {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                if regex.firstMatch(in: result, options: [], range: range) != nil {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: range,
                        withTemplate: ""
                    )
                    break
                }
            }
        }

        return result
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

        // Check for "in X minutes/hours" patterns first (with digits)
        let relativeTimePattern = #"in\s+(\d+)\s*(minutes?|mins?|hours?|hrs?|seconds?|secs?)"#
        if let regex = try? NSRegularExpression(pattern: relativeTimePattern, options: .caseInsensitive) {
            let range = NSRange(workingInput.startIndex..., in: workingInput)
            if let match = regex.firstMatch(in: workingInput, options: [], range: range) {
                if let numberRange = Range(match.range(at: 1), in: workingInput),
                   let unitRange = Range(match.range(at: 2), in: workingInput) {
                    let number = Int(workingInput[numberRange]) ?? 0
                    let unit = String(workingInput[unitRange]).lowercased()

                    var component: Calendar.Component = .minute
                    if unit.hasPrefix("hour") || unit.hasPrefix("hr") {
                        component = .hour
                    } else if unit.hasPrefix("sec") {
                        component = .second
                    }

                    foundDate = calendar.date(byAdding: component, value: number, to: Date())
                    hasSpecificTime = true

                    if let fullRange = Range(match.range, in: workingInput) {
                        workingInput.removeSubrange(fullRange)
                    }
                }
            }
        }

        // Check for word-based numbers ("in two minutes", "in three hours")
        let wordNumbers: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40,
            "forty-five": 45, "half": 30, "a": 1, "an": 1
        ]
        let wordPattern = #"in\s+(one|two|three|four|five|six|seven|eight|nine|ten|fifteen|twenty|thirty|forty|forty-five|half|a|an)\s*(minutes?|mins?|hours?|hrs?)"#
        if foundDate == nil, let regex = try? NSRegularExpression(pattern: wordPattern, options: .caseInsensitive) {
            let range = NSRange(workingInput.startIndex..., in: workingInput)
            if let match = regex.firstMatch(in: workingInput, options: [], range: range) {
                if let wordRange = Range(match.range(at: 1), in: workingInput),
                   let unitRange = Range(match.range(at: 2), in: workingInput) {
                    let word = String(workingInput[wordRange]).lowercased()
                    let unit = String(workingInput[unitRange]).lowercased()
                    let number = wordNumbers[word] ?? 1

                    var component: Calendar.Component = .minute
                    if unit.hasPrefix("hour") || unit.hasPrefix("hr") {
                        component = .hour
                    }

                    foundDate = calendar.date(byAdding: component, value: number, to: Date())
                    hasSpecificTime = true

                    if let fullRange = Range(match.range, in: workingInput) {
                        workingInput.removeSubrange(fullRange)
                    }
                }
            }
        }

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

        // Remove "remind me to", "remind me", "reminder to", "reminder" at the start
        let remindPatterns = [
            "^\\s*remind\\s+me\\s+to\\s+",
            "^\\s*remind\\s+me\\s+",
            "^\\s*reminder\\s+to\\s+",
            "^\\s*reminder\\s+",
            "^\\s*set\\s+a?\\s*reminder\\s+to\\s+",
            "^\\s*set\\s+a?\\s*reminder\\s+for\\s+",
        ]
        for pattern in remindPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }

        // Remove common preposition artifacts
        let artifacts = ["at", "on", "by", "for", "the", "in", "to"]
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
