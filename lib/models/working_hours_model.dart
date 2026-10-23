class WorkingDayHour {
  final int dayOfWeek; // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
  final String dayName;
  final String? openingTime; // "HH:mm"
  final String? closingTime; // "HH:mm"
  final bool isClosed;

  WorkingDayHour({
    required this.dayOfWeek,
    required this.dayName,
    this.openingTime,
    this.closingTime,
    required this.isClosed,
  });

  factory WorkingDayHour.fromJson(Map<String, dynamic> json) {
    return WorkingDayHour(
      dayOfWeek: json['day_of_week'] is int
          ? json['day_of_week'] as int
          : int.tryParse(json['day_of_week']?.toString() ?? '0') ?? 0,
      dayName: json['day_name']?.toString() ?? '',
      openingTime: json['opening_time']?.toString(),
      closingTime: json['closing_time']?.toString(),
      isClosed: json['is_closed'] == true ||
          json['is_closed'] == 1 ||
          json['is_closed'] == '1' ||
          json['is_closed'] == 'true',
    );
  }

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'day_name': dayName,
        'opening_time': openingTime,
        'closing_time': closingTime,
        'is_closed': isClosed,
      };

  /// Returns whether a given DateTime is within opening hours for this day
  bool isWithinHours(DateTime time) {
    if (isClosed) return false;
    if (openingTime == null || closingTime == null) return false;

    final openParts = parseTime(openingTime!);
    final closeParts = parseTime(closingTime!);
    if (openParts == null || closeParts == null) return false;

    final currentMinutes = time.hour * 60 + time.minute;
    final openMinutes = openParts[0] * 60 + openParts[1];
    final closeMinutes = closeParts[0] * 60 + closeParts[1];

    return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
  }

  static List<int>? parseTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        return [int.parse(parts[0]), int.parse(parts[1])];
      }
    } catch (_) {}
    return null;
  }
}

class BranchWorkingHours {
  final int branchId;
  final String branchName;
  final List<WorkingDayHour> hours;

  BranchWorkingHours({
    required this.branchId,
    required this.branchName,
    required this.hours,
  });

  factory BranchWorkingHours.fromJson(Map<String, dynamic> json) {
    final rawHours = json['hours'];
    final list = <WorkingDayHour>[];
    if (rawHours is List) {
      for (final item in rawHours) {
        if (item is Map) {
          list.add(WorkingDayHour.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return BranchWorkingHours(
      branchId: json['branch_id'] is int
          ? json['branch_id'] as int
          : int.tryParse(json['branch_id']?.toString() ?? '0') ?? 0,
      branchName: json['branch_name']?.toString() ?? '',
      hours: list,
    );
  }

  Map<String, dynamic> toJson() => {
        'branch_id': branchId,
        'branch_name': branchName,
        'hours': hours.map((h) => h.toJson()).toList(),
      };

  /// Returns the WorkingDayHour for a given DateTime (Sunday = 0, Monday = 1, ..., Saturday = 6)
  WorkingDayHour? getDayHour(DateTime date) {
    final int backendDayOfWeek = date.weekday % 7;
    try {
      return hours.firstWhere((h) => h.dayOfWeek == backendDayOfWeek);
    } catch (_) {
      return null;
    }
  }

  /// Evaluates whether the branch is currently open
  WorkingHoursStatus checkStatus([DateTime? now]) {
    final current = now ?? DateTime.now();
    final dayHour = getDayHour(current);
    if (dayHour == null) {
      return WorkingHoursStatus(
        isOpen: true,
        todayHour: null,
        message: 'Operating hours not configured.',
      );
    }

    if (dayHour.isClosed) {
      return WorkingHoursStatus(
        isOpen: false,
        todayHour: dayHour,
        message: 'Branch is closed on ${dayHour.dayName}s.',
      );
    }

    if (dayHour.isWithinHours(current)) {
      return WorkingHoursStatus(
        isOpen: true,
        todayHour: dayHour,
        message: 'Open today until ${dayHour.closingTime}.',
      );
    }

    final openParts = WorkingDayHour.parseTime(dayHour.openingTime ?? '');
    final currentMinutes = current.hour * 60 + current.minute;
    if (openParts != null && currentMinutes < (openParts[0] * 60 + openParts[1])) {
      return WorkingHoursStatus(
        isOpen: false,
        todayHour: dayHour,
        message: 'Branch is not open yet. Today\'s hours: ${dayHour.openingTime} - ${dayHour.closingTime}.',
      );
    }

    return WorkingHoursStatus(
      isOpen: false,
      todayHour: dayHour,
      message: 'Branch is closed for the day. Today\'s hours were: ${dayHour.openingTime} - ${dayHour.closingTime}.',
    );
  }
}

class WorkingHoursStatus {
  final bool isOpen;
  final WorkingDayHour? todayHour;
  final String message;

  WorkingHoursStatus({
    required this.isOpen,
    this.todayHour,
    required this.message,
  });
}
