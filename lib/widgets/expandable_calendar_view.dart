import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum CalendarDisplayMode { week, month }

class ExpandableCalendarView extends StatefulWidget {
  final List<String> bookedDates;
  final DateTime? selectedStartDate;
  final DateTime? selectedEndDate;
  final void Function(DateTime startDate, DateTime endDate)? onDateRangeSelected;
  final void Function(String message)? onSelectionInvalid;

  const ExpandableCalendarView({
    super.key,
    required this.bookedDates,
    this.selectedStartDate,
    this.selectedEndDate,
    this.onDateRangeSelected,
    this.onSelectionInvalid,
  });

  @override
  State<ExpandableCalendarView> createState() => _ExpandableCalendarViewState();
}

class _ExpandableCalendarViewState extends State<ExpandableCalendarView> {
  CalendarDisplayMode _displayMode = CalendarDisplayMode.week;
  late DateTime _visibleDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleDate = DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime? b) {
    if (b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateKey(DateTime d) {
    return "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  bool _isDateBooked(DateTime d) {
    return widget.bookedDates.contains(_formatDateKey(d));
  }

  void _onDateSelected(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.isBefore(today)) return;
    if (_isDateBooked(date)) {
      widget.onSelectionInvalid?.call('Tanggal ini sudah dibooking.');
      return;
    }

    // Default range is 3 days (date to date + 2 days, min 3 days rental)
    final startDate = date;
    final endDate = date.add(const Duration(days: 2));

    // Verify no dates in the 3-day range are booked
    bool isRangeBooked = false;
    var curr = startDate;
    while (!curr.isAfter(endDate)) {
      if (_isDateBooked(curr)) {
        isRangeBooked = true;
        break;
      }
      curr = curr.add(const Duration(days: 1));
    }

    if (isRangeBooked) {
      widget.onSelectionInvalid?.call(
          'Satu atau lebih tanggal dalam rentang 3 hari ini sudah dibooking.');
    } else {
      widget.onDateRangeSelected?.call(startDate, endDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final monthName = DateFormat('MMMM yyyy').format(_visibleDate);

    // Compute dates for the grid
    final List<DateTime> dates;
    if (_displayMode == CalendarDisplayMode.week) {
      // Sunday-start week
      final sundayOffset = _visibleDate.weekday % 7;
      final firstDayOfWeek = _visibleDate.subtract(Duration(days: sundayOffset));
      dates = List.generate(
          7, (i) => firstDayOfWeek.add(Duration(days: i)));
    } else {
      final firstDayOfMonth = DateTime(_visibleDate.year, _visibleDate.month, 1);
      final sundayOffset = firstDayOfMonth.weekday % 7;
      final firstDayOfGrid = firstDayOfMonth.subtract(Duration(days: sundayOffset));
      dates = List.generate(
          42, (i) => firstDayOfGrid.add(Duration(days: i)));
    }

    final weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () {
                setState(() {
                  _visibleDate = DateTime(
                      _visibleDate.year, _visibleDate.month - 1, _visibleDate.day);
                });
              },
            ),
            Text(
              monthName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _displayMode == CalendarDisplayMode.week
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                  ),
                  tooltip: _displayMode == CalendarDisplayMode.week
                      ? 'Expand Month'
                      : 'Collapse Week',
                  onPressed: () {
                    setState(() {
                      _displayMode = _displayMode == CalendarDisplayMode.week
                          ? CalendarDisplayMode.month
                          : CalendarDisplayMode.week;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  onPressed: () {
                    setState(() {
                      _visibleDate = DateTime(
                          _visibleDate.year, _visibleDate.month + 1, _visibleDate.day);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Weekday labels
        Row(
          children: weekdays.map((day) {
            return Expanded(
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),

        // Dates Grid
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: dates.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            final date = dates[index];
            final dateOnly = DateTime(date.year, date.month, date.day);
            final isToday = _isSameDay(dateOnly, today);
            final isPastDate = dateOnly.isBefore(today);
            final isBooked = _isDateBooked(dateOnly);
            final isClickable = !isBooked && !isPastDate;
            final isFromCurrentMonth = date.month == _visibleDate.month;

            final isStart = _isSameDay(dateOnly, widget.selectedStartDate);
            final isEnd = _isSameDay(dateOnly, widget.selectedEndDate);
            final isSelected = isStart || isEnd;
            final isInRange = widget.selectedStartDate != null &&
                widget.selectedEndDate != null &&
                dateOnly.isAfter(widget.selectedStartDate!) &&
                dateOnly.isBefore(widget.selectedEndDate!);

            Color boxColor = Colors.transparent;
            Color textColor = theme.colorScheme.onSurface;
            TextDecoration decoration = TextDecoration.none;

            if (isSelected) {
              boxColor = theme.colorScheme.primary;
              textColor = theme.colorScheme.onPrimary;
            } else if (isInRange) {
              boxColor = theme.colorScheme.primaryContainer.withValues(alpha: 0.7);
              textColor = theme.colorScheme.onPrimaryContainer;
            } else if (isBooked) {
              boxColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
              textColor = theme.colorScheme.onSurface.withValues(alpha: 0.35);
              decoration = TextDecoration.lineThrough;
            } else if (isPastDate) {
              textColor = Colors.grey.shade400;
            } else if (!isFromCurrentMonth) {
              textColor = theme.colorScheme.onSurface.withValues(alpha: 0.3);
            }

            return InkWell(
              onTap: isClickable ? () => _onDateSelected(dateOnly) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: boxColor,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected && !isBooked
                      ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${date.day}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    decoration: decoration,
                    decorationColor: Colors.red.shade400,
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 8),

        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(
              color: theme.colorScheme.primary,
              label: 'Selected',
              isCircle: true,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: theme.colorScheme.surfaceContainerHighest,
              label: 'Booked',
              isStrikethrough: true,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: Colors.transparent,
              borderColor: theme.colorScheme.primary,
              label: 'Today',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color? borderColor;
  final String label;
  final bool isCircle;
  final bool isStrikethrough;

  const _LegendItem({
    required this.color,
    this.borderColor,
    required this.label,
    this.isCircle = true,
    this.isStrikethrough = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: isStrikethrough
              ? Text(
                  '—',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
