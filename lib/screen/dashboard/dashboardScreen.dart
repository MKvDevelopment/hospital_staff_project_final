import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hospital_staff_project/common_code/custom_text_style.dart';
import 'package:hospital_staff_project/screen/auth/StudentModel.dart';
import 'package:hospital_staff_project/screen/dashboard/profileUpdate.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../provider/AppoitmentProvider.dart';
import '../../provider/doctor_provider.dart';
import '../../route_constants.dart';
import '../doctorManagement/doctorModel.dart';
import '../patientManagementScreen/AppointmentModel.dart';
import 'package:file_picker/file_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String userName = ''; // Default placeholder
  String userEmail = ''; // Default placeholder
  String userImage = ''; // Placeholder for user image URL
  String? uploadedFileURL;
  bool isUploading = false;

  void fetchUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection(
                'staff_data') // Replace 'users' with your Firestore collection name
            .doc(currentUser.uid) // Get the document using the user's UID
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          setState(() {
            userName = data['name'] ?? 'No Name'; // Update name
            userEmail = data['email'] ?? 'No Email'; // Update email
            userImage = data['imageUrl'] ?? ''; // Update image URL
          });
        } else {
          print('User document does not exist');
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    Provider.of<DoctorProvider>(context, listen: false).fetchDoctors();

    Provider.of<AppointmentProvider>(context, listen: false)
        .fetchAppointments();
    fetchUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.red, // Customize your AppBar background color
        title: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white,
              child: Image.asset(
                'assets/icons/doctorIcon.png',
                width: 35,
                height: 35,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              // Align text vertically
              children: [
                Text(
                  userName,
                  style: CustomTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  userEmail,
                  style:
                      CustomTextStyles.titleSmall.copyWith(color: Colors.white),
                ),
              ],
            ),
            const Spacer(),
            CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                child: IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const ProfileUpdateDialog(),
                      );
                    },
                    icon: const Icon(Icons.person))),
            const SizedBox(width: 10),
            CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                child: IconButton(
                    onPressed: () {
                      _showLogoutDialog(context);
                    },
                    icon: const Icon(Icons.logout))),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Selection
              SizedBox(
                height: 230,
                child: Consumer<DoctorProvider>(
                  builder: (context, appoitmentProvider, child) {
                    final allDoctorsList = appoitmentProvider.doctors
                        .where((doctor) => doctor.availabilityStatus == "true")
                        .toList();

                    return allDoctorsList.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Doctors Availability (${allDoctorsList.length})",
                                style: CustomTextStyles.titleSmall
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(
                                height: 210,
                                width: double.infinity,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: allDoctorsList.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: _availabilityCard(
                                          allDoctorsList[index]),
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Text(
                              'No Doctors Available',
                              style: CustomTextStyles.titleMedium,
                            ),
                          );
                  },
                ),
              ),
              const Divider(
                color: Colors.grey,
              ),
              Consumer<AppointmentProvider>(
                  builder: (context, appoitmentProvider, child) {
                // Get today's date (only the date portion)
                final today = DateTime.now();
                final todayOnly = DateTime(today.year, today.month, today.day);

                // Filter appointments for today
                var todayAppointments =
                    appoitmentProvider.upcomingAppointments.where(
                  (appointment) {
                    try {
                      // Parse the appointment date string
                      final appointmentDate = DateTime.parse(appointment
                          .date); // Ensure date is in 'yyyy-MM-dd' format
                      final appointmentOnlyDate = DateTime(
                        appointmentDate.year,
                        appointmentDate.month,
                        appointmentDate.day,
                      );

                      // Compare only the date parts
                      return appointmentOnlyDate == todayOnly;
                    } catch (e) {
                      print('Error parsing date: ${appointment.date}');
                      return false; // Skip invalid dates
                    }
                  },
                ).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Today's Appointments",
                          style: CustomTextStyles.titleSmall
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                            onPressed: () {
                              Provider.of<AppointmentProvider>(context,
                                      listen: false)
                                  .fetchAppointments();
                            },
                            icon: const Icon(Icons.refresh)),
                      ],
                    ),
                    todayAppointments.isNotEmpty
                        ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            // Disables internal scrolling

                            itemCount: todayAppointments.length,
                            itemBuilder: (context, index) {
                              final appointment = todayAppointments[index];
                              return _appointmentCard(appointment);
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: Center(
                              child: Text('No Appointments',
                                  style: CustomTextStyles.titleMedium),
                            ),
                          ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _availabilityCard(DoctorModel appointment) {
    return Card(
      color: Colors.red.shade50,
      elevation: 5,
      margin: const EdgeInsets.all(5),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: appointment.imgUrl.isNotEmpty
                      ? Image.network(
                          'https://cors-anywhere.herokuapp.com/${appointment.imgUrl}',
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.red,
                            ),
                          );
                        })
                      : Image.asset(
                          "assets/images/lady.png",
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error),
                        ),
                )),
            Text(appointment.doctorName,
                style: CustomTextStyles.titleSmall.copyWith(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            Text(appointment.department,
                style:
                    CustomTextStyles.titleSmall.copyWith(color: Colors.grey)),
            Text("Experience: ${appointment.experience} years",
                style:
                    CustomTextStyles.titleSmall.copyWith(color: Colors.grey)),
            appointment.availabilityStatus.toString() == "true"
                ? Text("Available\n${appointment.availabilityTime}",
                    textAlign: TextAlign.center,
                    style: CustomTextStyles.titleSmall
                        .copyWith(color: Colors.green))
                : Text("Not Available",
                    style: CustomTextStyles.titleSmall
                        .copyWith(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _appointmentCard(AppointmenModel appointment) {
    AppointmentProvider provider =
        Provider.of<AppointmentProvider>(context, listen: false);
    return FutureBuilder<StudentModel?>(
      future: provider.fetchStudentById(appointment.userId),
      // future: fetchStudentById(appointment.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.only(top: 10),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                  child: CircularProgressIndicator(
                color: Colors.red,
              )),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.only(top: 10),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Error loading student details',
                  style: CustomTextStyles.titleMedium,
                ),
              ),
            ),
          );
        }

        final student = snapshot.data;
        return Card(
          color: Colors.red.shade50,
          margin: const EdgeInsets.only(top: 10),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 65,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: student?.imgUrl != null &&
                              student!.imgUrl.isNotEmpty
                          ? Image.network(
                              'https://cors-anywhere.herokuapp.com/${student.imgUrl}',
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120, loadingBuilder:
                                  (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.red,
                                ),
                              );
                            })
                          : Image.asset(
                              "assets/images/lady.png",
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error),
                            ),
                    )),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${appointment.doctorName} (${appointment.category})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: CustomTextStyles.titleSmall.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                      Text("Time: ${appointment.time}",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: CustomTextStyles.titleSmall
                              .copyWith(color: Colors.grey)),
                      student != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Patient Name : ${student.name}",
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: CustomTextStyles.titleSmall
                                        .copyWith(color: Colors.black)),
                                Text("Contact Detail: ${student.mobileNo}",
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: CustomTextStyles.titleSmall
                                        .copyWith(color: Colors.black)),
                              ],
                            )
                          : Text(
                              'No student data available',
                              style: CustomTextStyles.titleSmall
                                  .copyWith(color: Colors.red),
                            ),
                      appointment.verification == 'approved'
                          ? Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.green.shade500,
                                      side: const BorderSide(
                                          color: Colors.white, width: 1),
                                    ),
                                    onPressed: () {},
                                    child: Text(
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      'Approved',
                                      style: CustomTextStyles.titleMedium
                                          .copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child: isUploading
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                          color: Colors.grey,
                                        ))
                                      : OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor:
                                                Colors.grey.shade500,
                                            side: const BorderSide(
                                                color: Colors.white, width: 1),
                                          ),
                                          onPressed: () {
                                            uploadPrescription();
                                          },
                                          child: Text(
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            'Upload Prescription',
                                            style: CustomTextStyles.titleMedium
                                                .copyWith(color: Colors.white),
                                          ),
                                        ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child: provider.isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                          color: Colors.grey,
                                        ))
                                      : OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor:
                                                uploadedFileURL == null ||
                                                        uploadedFileURL!.isEmpty
                                                    ? Colors.grey.shade300
                                                    : Colors.red.shade500,
                                            side: const BorderSide(
                                                color: Colors.white, width: 1),
                                          ),
                                          onPressed: uploadedFileURL == null ||
                                                  uploadedFileURL!.isEmpty
                                              ? null // Disable the button
                                              : () {
                                                  // Your action when the button is enabled
                                                  Provider.of<AppointmentProvider>(
                                                          context,
                                                          listen: false)
                                                      .completePatientAppointment(
                                                          appointment.id,
                                                          context,
                                                          uploadedFileURL!);
                                                },
                                          child: Text(
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            'Complete',
                                            style: CustomTextStyles.titleMedium
                                                .copyWith(
                                              color: uploadedFileURL == null ||
                                                      uploadedFileURL!.isEmpty
                                                  ? Colors
                                                      .grey // Text color when disabled
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            )
                          : OutlinedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => _buildQRCodeDialog(
                                      context,
                                      "${appointment.userId},${appointment.id}"),
                                );
                              },
                              child: Text(
                                'Scan Code for Meeting',
                                style: CustomTextStyles.titleMedium,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQRCodeDialog(BuildContext context, String qrData) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: SizedBox(
        width: 350,
        height: 350,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
              child: QrImageView(
                  data: qrData, version: QrVersions.auto, size: 300.0)),
        ),
      ),
    );
  }

  // Function to show the logout confirmation dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Logout',
            style: CustomTextStyles.titleLarge,
          ),
          content: Text(
            'Are you sure you want to log out?',
            style: CustomTextStyles.titleMedium,
          ),
          actions: <Widget>[
            // Cancel button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            // Confirm button
            TextButton(
              onPressed: () {
                // Perform the logout action here
                _logout(context);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  // Logout logic (you can modify this as per your application needs)
  void _logout(BuildContext context) {
    FirebaseAuth.instance.signOut();
    // You can handle the actual logout here (clear session, tokens, etc.)
    Navigator.of(context).pop(); // Close the dialog
    Navigator.pushNamedAndRemoveUntil(
        context, logInScreenRoute, (route) => false);
  }

  Future<void> uploadPrescription() async {
    // Pick a file
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'], // Restrict to PDF and DOC
    );

    if (result != null) {
      Uint8List? fileBytes = result.files.first.bytes; // File as bytes
      String fileName = result.files.first.name; // File name

      try {
        setState(() {
          isUploading = true;
        });

        // Upload file to Firebase Storage
        Reference storageRef =
            FirebaseStorage.instance.ref('prescriptionsFile/$fileName');
        UploadTask uploadTask = storageRef.putData(fileBytes!);

        await uploadTask;

        // Get the file's download URL
        String downloadURL = await storageRef.getDownloadURL();

        setState(() {
          uploadedFileURL = downloadURL;
          isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload successful!')),
        );
      } catch (e) {
        setState(() {
          isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }
}
