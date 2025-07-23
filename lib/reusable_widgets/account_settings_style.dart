import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

/* Esta página é auxiliar á pagina account_settings.dart e é responsável por criar o seguinte:
- Os botões do Account Settings
- A animação quando se passa o cursor por cima de cada botão (_buildQuickActionButton) 
- O calendário e as atividades do Activity History (calendarDialog)(activitiesDialog)*/

class AccountSettingsWidgets {
  static List<Widget> buildButtonList({
    required BuildContext context,
    required bool isSetupComplete,
    required String? storeNumber,
    required String? nickname,
    required Set<DateTime> daysWithActivities,
    required DateTime focusedDay,
    required DateTime? selectedDay,
    required VoidCallback onStoreNumberPressed,
    required VoidCallback onPersonalInfoPressed,
    required VoidCallback onPasswordPressed,
    required VoidCallback onActivitiesPressed,
    required VoidCallback onTermsPressed,
    required Function(DateTime, DateTime) onCalendarDaySelected,
  }) {
    final buttons = [
      _buildQuickActionButton(
        context,
        "See Store Number",
        Icons.store,
        "Have access to your store number.",
        onPressed: onStoreNumberPressed,
      ),
      _buildQuickActionButton(
        context,
        "Edit Account Information",
        Icons.person,
        "Update your personal information.",
        onPressed: onPersonalInfoPressed,
      ),
      _buildQuickActionButton(
        context,
        "Change Password",
        Icons.lock,
        "Change your credentials, via email",
        onPressed: onPasswordPressed,
      ),
      _buildQuickActionButton(
        context,
        "Activity History",
        Icons.history,
        "View employee schedules by date",
        onPressed: onActivitiesPressed,
        isEnabled: isSetupComplete,
      ),
      _buildQuickActionButton(
        context,
        "Privacy Policy",
        Icons.privacy_tip,
        "View our terms and conditions",
        onPressed: onTermsPressed,
      ),
    ];

    return buttons.expand((button) => [button, const SizedBox(height: 20)]).toList();
  }

  static Widget _buildQuickActionButton(
    BuildContext context,
    String title,
    IconData icon,
    String description, {
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    bool _isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = isEnabled),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: MediaQuery.of(context).size.width * 0.4,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _isHovered
                    ? Colors.blue[100]
                    : Colors.white.withOpacity(isEnabled ? 1.0 : 0.6),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isHovered ? 0.3 : 0.2),
                    spreadRadius: 2, blurRadius: 10,
                    offset: Offset(0, _isHovered ? 8 : 4),
                  ),
                ],
                border: Border.all(color: _isHovered ? Colors.black : Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  AnimatedScale(
                    scale: _isHovered ? 1.5 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(icon, color: Colors.black.withOpacity(isEnabled ? 1.0 : 0.6), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.8,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            title,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                                color: Colors.black
                                    .withOpacity(isEnabled ? 1.0 : 0.6)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedOpacity(
                          opacity: _isHovered ? 1.0 : 0.6,
                          duration: const Duration(milliseconds: 300),
                          child: Text(description,
                              style: TextStyle(fontSize: 14,
                                  color: Colors.black.withOpacity(isEnabled ? 0.7 : 0.5))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget calendarDialog({
    required BuildContext context,
    required String? storeNumber,
    required Set<DateTime> daysWithActivities,
    required DateTime focusedDay,
    required DateTime? selectedDay,
    required Function(DateTime, DateTime) onDaySelected,
  }) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Store $storeNumber - ',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      const TextSpan(
                        text: 'Select Date',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 30)),
                  lastDay: DateTime.now(),
                  focusedDay: focusedDay,
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  onDaySelected: onDaySelected,
                  calendarStyle: CalendarStyle(
                    cellMargin: const EdgeInsets.all(1),
                    defaultTextStyle: const TextStyle(fontSize: 12),
                    todayTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    selectedTextStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                    defaultDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!)),
                    selectedDecoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(
                        color: Colors.purpleAccent, width: 1.5,
                      ),
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    headerMargin: EdgeInsets.only(bottom: 4),
                    titleTextStyle: TextStyle(fontSize: 14),
                    leftChevronIcon: Icon(Icons.chevron_left, size: 20),
                    rightChevronIcon: Icon(Icons.chevron_right, size: 20),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(fontSize: 10),
                    weekendStyle: TextStyle(fontSize: 10),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final hasActivity = daysWithActivities.contains(DateTime(day.year, day.month, day.day));
                      return Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasActivity ? Colors.blue : Colors.grey[300]!, width: hasActivity ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(fontSize: 12,
                              color: isSameDay(selectedDay, day)
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  rowHeight: 36, daysOfWeekHeight: 24,
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(fontSize: 14))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget activitiesDialog({
    required BuildContext context,
    required DateTime date,
    required Map<String, List<Map<String, dynamic>>> activitiesByUser,
    required VoidCallback onBackPressed,
  }) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  'Activities for ${DateFormat('dd/MM/yyyy').format(date)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              if (activitiesByUser.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, bottom: 16.0),
                      child: Text('No activities found for this date'),
                    ),
                    const Divider(height: 16),
                  ],
                )
              else
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...activitiesByUser.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 4),
                              child: Text(entry.key,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            ...entry.value.map((activity) => Padding(
                                  padding: const EdgeInsets.only(left: 8.0, top: 4),
                                  child: Text(
                                    '• ${activity['action']} at ${activity['time']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                )),
                            const Divider(height: 16),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Center(
                child: Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: onBackPressed,
                      child: const Text('Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}