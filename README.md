#Attendance System

A comprehensive Flutter-based attendance management system for Gajanan Vidyalaya Deodhanora Tq Kallam.

## Features

### 🏢 User Management
- **Add Staff & Students**: Easy addition of staff members and students with auto-assigned codes
- **Edit Users**: Modify existing user information including name, code, and role
- **Delete Users**: Remove users with confirmation dialogs
- **Search & Filter**: Find users by name or code, filter by role (Staff/Student)

### 📅 Attendance Tracking
- **Monthly View**: Calendar-style interface for managing attendance
- **Status Marking**: Mark users as Present (P), Absent (A), or Leave (L)
- **Holiday Management**: Set and manage holidays for each month
- **Week Off**: Automatic marking of Sundays as Week Off (WO)

### 📊 Excel Export
- **Comprehensive Reports**: Export detailed attendance reports in Excel format
- **Professional Formatting**: Includes company header, date information, and summaries
- **Multiple Sections**: Separate sections for Staff and Students
- **Summary Statistics**: Total counts and holiday information included

### 🎨 User Interface
- **Modern Design**: Clean, intuitive interface with Material Design
- **Color Coding**: Different colors for Staff (Green) and Students (Orange)
- **Statistics Dashboard**: Real-time counts and overview
- **Responsive Layout**: Works on various screen sizes

## How to Use

### Adding Users
1. Click "Add Staff" or "Add Student" button
2. Enter the full name
3. Optionally enter a specific code (auto-assigned if left empty)
4. Click "Save"

### Managing Attendance
1. Click "Attendance & Holidays" button
2. Select the desired month
3. Set holidays by clicking on day numbers
4. Mark attendance by tapping on user-day cells
5. Choose status: Present, Leave, or Absent

### Exporting Reports
1. Click "Export Excel" button
2. Select the month to export
3. Choose save location
4. Report will be generated with all attendance data

### User Management
1. Click "Manage Users" button
2. View all users with search and filter options
3. Edit or delete users as needed
4. See statistics and user details

## Technical Details

- **Framework**: Flutter
- **Database**: SQLite with sqflite
- **Excel Export**: excel package
- **File Management**: file_picker and open_file packages
- **Date Handling**: intl package

## Installation

1. Ensure Flutter is installed on your system
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the application

## File Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── person.dart          # Person data model
├── db/
│   └── database_helper.dart # Database operations
└── screens/
    ├── home_screen.dart     # Main dashboard
    ├── add_person.dart      # Add user screen
    ├── edit_person.dart     # Edit user screen
    ├── user_details_screen.dart # User management
    └── month_screen.dart    # Attendance management
```

## Database Schema

- **persons**: User information (id, name, empCode, role)
- **holidays**: Holiday dates (id, year, month, day)
- **leaves**: Attendance records (id, personId, year, month, day, type)

## Support

For any issues or questions, please contact the development team.
