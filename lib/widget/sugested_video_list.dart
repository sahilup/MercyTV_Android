import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mercy_tv_app/API/api_integration.dart';
import 'package:mercy_tv_app/API/dataModel.dart';
import 'package:mercy_tv_app/Colors/custom_color.dart';
import 'package:mercy_tv_app/controllers/home_controller.dart';

class SuggestedVideoCard extends StatefulWidget {
  final void Function(ProgramDetails) onVideoTap;

  const SuggestedVideoCard({super.key, required this.onVideoTap});

  @override
  _SuggestedVideoCardState createState() => _SuggestedVideoCardState();
}

class _SuggestedVideoCardState extends State<SuggestedVideoCard> {
  late Future<List<dynamic>> _videoDataFuture;
  List<dynamic> _videoData = [];

  @override
  void initState() {
    super.initState();
    _videoDataFuture = _fetchSortedVideoData();
  }

  Future<List<dynamic>> _fetchSortedVideoData() async {
    List<dynamic> data = await ApiIntegration().getVideoData();
    data.sort((a, b) => int.parse(b['video_id']).compareTo(int.parse(a['video_id'])));
    return data; // Full list
  }

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = Get.put(HomeController());

    return FutureBuilder<List<dynamic>>(
      future: _videoDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return SizedBox(
            height: 200,
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No videos available')),
          );
        } else {
          _videoData = snapshot.data!;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 15,
              childAspectRatio: 1.5,
            ),
            itemCount: _videoData.length,
            itemBuilder: (context, index) {
              var video = _videoData[index];
              var program = video['program'] ?? {};

              ProgramDetails programDetails = ProgramDetails(
                imageUrl: program['image'],
                date: program['date'],
                time: program['time'],
                title: program['program'] ?? 'Unknown Program',
                videoUrl: video['url'],
              );

              return Obx(
                () => VideoThumbnailCard(
                  programDetails: programDetails,
                  isPlaying: homeController.currentlyPlayingIndex?.value == index,
                  onTap: (details) {
                    homeController.currentlyPlayingIndex?.value = index;
                    widget.onVideoTap(details);
                  },
                ),
              );
            },
          );
        }
      },
    );
  }
}

class VideoThumbnailCard extends StatelessWidget {
  final ProgramDetails programDetails;
  final bool isPlaying;
  final void Function(ProgramDetails) onTap;

  const VideoThumbnailCard({
    super.key,
    required this.programDetails,
    required this.isPlaying,
    required this.onTap,
  });

  String formatDateTime(String? date, String? time) {
    if (date == null || time == null) return "Unknown Date";
    try {
      DateTime parsedDate = DateTime.parse(date);
      List<String> timeParts = time.split(":");
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      String formattedDate =
          "${parsedDate.day} ${_getMonth(parsedDate.month)} ${parsedDate.year}";
      String formattedTime = _formatTime(hour, minute);
      return "$formattedDate | $formattedTime";
    } catch (e) {
      return "Invalid Date/Time";
    }
  }

  String _formatTime(int hour, int minute) {
    final String period = hour < 12 ? "AM" : "PM";
    final int displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final String minuteStr = minute.toString().padLeft(2, '0');
    return "$displayHour:$minuteStr $period";
  }

  static String _getMonth(int month) {
    const months = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(programDetails),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isPlaying
              ? Border.all(color: CustomColors.buttonColor, width: 2)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: 'https://mercyott.com/${programDetails.imageUrl ?? ''}',
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => Image.asset(
                  'assets/images/video_thumb_1.png',
                  fit: BoxFit.cover,
                ),
                fadeInDuration: const Duration(milliseconds: 200),
                fadeOutDuration: const Duration(milliseconds: 200),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      programDetails.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Mulish-Medium',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.history,
                            color: CustomColors.buttonColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          formatDateTime(programDetails.date, programDetails.time),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Mulish-Medium',
                          ),
                        ),
                      ],
                    ),
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