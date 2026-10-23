import 'package:flutter_test/flutter_test.dart';
import 'package:deresegn/models/working_hours_model.dart';

void main() {
  group('Branch Working Hours Models & Calculations', () {
    test('WorkingDayHour deserializes and serializes accurately', () {
      final json = {
        'day_of_week': 1,
        'day_name': 'Monday',
        'opening_time': '09:00',
        'closing_time': '17:00',
        'is_closed': false,
      };

      final hour = WorkingDayHour.fromJson(json);
      expect(hour.dayOfWeek, 1);
      expect(hour.dayName, 'Monday');
      expect(hour.openingTime, '09:00');
      expect(hour.closingTime, '17:00');
      expect(hour.isClosed, false);
      expect(hour.toJson(), equals(json));
    });

    test('isWithinHours returns true during active open hours', () {
      final hour = WorkingDayHour(
        dayOfWeek: 1,
        dayName: 'Monday',
        openingTime: '09:00',
        closingTime: '17:00',
        isClosed: false,
      );

      // 12:30 PM -> Within hours
      final insideTime = DateTime(2026, 9, 28, 12, 30); // Monday
      expect(hour.isWithinHours(insideTime), isTrue);

      // Exactly at 09:00 -> Within hours
      final openBorder = DateTime(2026, 9, 28, 9, 0);
      expect(hour.isWithinHours(openBorder), isTrue);

      // 08:59 AM -> Before opening
      final beforeTime = DateTime(2026, 9, 28, 8, 59);
      expect(hour.isWithinHours(beforeTime), isFalse);

      // 17:00 -> Closing time (excluded)
      final atCloseTime = DateTime(2026, 9, 28, 17, 0);
      expect(hour.isWithinHours(atCloseTime), isFalse);

      // 19:30 -> After closing
      final afterTime = DateTime(2026, 9, 28, 19, 30);
      expect(hour.isWithinHours(afterTime), isFalse);
    });

    test('isWithinHours always returns false when isClosed is true', () {
      final closedHour = WorkingDayHour(
        dayOfWeek: 6,
        dayName: 'Saturday',
        openingTime: null,
        closingTime: null,
        isClosed: true,
      );

      final saturdayNoon = DateTime(2026, 10, 3, 12, 0); // Saturday
      expect(closedHour.isWithinHours(saturdayNoon), isFalse);
    });

    test('BranchWorkingHours parses complete 7-day schedule from API response', () {
      final sampleApiResponse = {
        "branch_id": 28,
        "branch_name": "Head Office",
        "hours": [
          {
            "day_of_week": 0,
            "day_name": "Sunday",
            "opening_time": "09:00",
            "closing_time": "17:00",
            "is_closed": false
          },
          {
            "day_of_week": 1,
            "day_name": "Monday",
            "opening_time": "09:00",
            "closing_time": "17:00",
            "is_closed": false
          },
          {
            "day_of_week": 2,
            "day_name": "Tuesday",
            "opening_time": "09:00",
            "closing_time": "17:00",
            "is_closed": false
          },
          {
            "day_of_week": 3,
            "day_name": "Wednesday",
            "opening_time": "09:00",
            "closing_time": "17:00",
            "is_closed": false
          },
          {
            "day_of_week": 4,
            "day_name": "Thursday",
            "opening_time": "09:00",
            "closing_time": "17:00",
            "is_closed": false
          },
          {
            "day_of_week": 5,
            "day_name": "Friday",
            "opening_time": "09:00",
            "closing_time": "14:00",
            "is_closed": false
          },
          {
            "day_of_week": 6,
            "day_name": "Saturday",
            "opening_time": null,
            "closing_time": null,
            "is_closed": true
          }
        ]
      };

      final schedule = BranchWorkingHours.fromJson(sampleApiResponse);
      expect(schedule.branchId, 28);
      expect(schedule.branchName, 'Head Office');
      expect(schedule.hours.length, 7);

      // Verify mapping for Sunday (backend day 0, Dart weekday 7)
      final sundayDate = DateTime(2026, 9, 27, 10, 0); // Sunday 10 AM
      expect(sundayDate.weekday, 7);
      expect(schedule.getDayHour(sundayDate)?.dayOfWeek, 0);
      expect(schedule.getDayHour(sundayDate)?.dayName, 'Sunday');

      // Verify mapping for Saturday (backend day 6, Dart weekday 6)
      final saturdayDate = DateTime(2026, 10, 3, 11, 0); // Saturday
      expect(saturdayDate.weekday, 6);
      final satHour = schedule.getDayHour(saturdayDate);
      expect(satHour?.dayOfWeek, 6);
      expect(satHour?.isClosed, isTrue);

      // Status check on Friday afternoon after 14:00
      final fridayAfterClose = DateTime(2026, 10, 2, 14, 30); // Friday 14:30
      final fridayStatus = schedule.checkStatus(fridayAfterClose);
      expect(fridayStatus.isOpen, isFalse);
      expect(fridayStatus.message, contains('closed for the day'));

      // Status check on Friday morning at 10:00
      final fridayOpen = DateTime(2026, 10, 2, 10, 0);
      final fridayOpenStatus = schedule.checkStatus(fridayOpen);
      expect(fridayOpenStatus.isOpen, isTrue);
      expect(fridayOpenStatus.message, contains('Open today until 14:00'));

      // Status check on Saturday (Closed all day)
      final satStatus = schedule.checkStatus(saturdayDate);
      expect(satStatus.isOpen, isFalse);
      expect(satStatus.message, contains('Branch is closed on Saturdays'));

      // Status check on Monday early morning before 09:00
      final mondayEarly = DateTime(2026, 9, 28, 7, 30);
      final mondayEarlyStatus = schedule.checkStatus(mondayEarly);
      expect(mondayEarlyStatus.isOpen, isFalse);
      expect(mondayEarlyStatus.message, contains('not open yet'));
    });
  });
}
