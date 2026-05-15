import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart'; // Import the package

class ScrollingBanner extends StatefulWidget {
  final Color? bgColor;
  const ScrollingBanner({Key? key, this.bgColor}) : super(key: key);

  @override
  State<ScrollingBanner> createState() => _ScrollingBannerState();
}

class _ScrollingBannerState extends State<ScrollingBanner> {
  @override
  Widget build(BuildContext classContext) {
    // 👈 Removed 'Expanded' from here so it's flexible
    return Container(
      height:
          40.0, // Reduced height slightly to look cleaner on mobile top bars
      color: widget.bgColor ?? Color(0xFF2C3E50),
      child: Marquee(
        text:
            'Welcome to Travelista, your smart and convenient travel companion. Travelista is an innovative travel agency website designed to make travel planning easier, faster, and more enjoyable for everyone. Our platform allows customers to book flights, tours, hotels, and travel packages in just a few clicks. What makes Travelista unique is our built-in AI assistant that helps clients with their travel concerns anytime. Customers can ask questions, get travel recommendations, check destinations, and receive instant assistance for their travel needs. At Travelista, our goal is to provide a hassle-free and user-friendly experience while helping travelers explore the world with confidence and convenience. Whether you are planning a vacation, business trip, or adventure getaway, Travelista is here to guide you every step of the way.',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14, // Slightly smaller text fits mobile better
          color: Colors.white,
        ),
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.center,
        blankSpace: 20.0,
        velocity: 30.0,
        pauseAfterRound: const Duration(seconds: 1),
        startPadding: 10.0,
        accelerationDuration: const Duration(seconds: 1),
        accelerationCurve: Curves.linear,
        decelerationDuration: const Duration(milliseconds: 500),
        decelerationCurve: Curves.easeOut,
      ),
    );
  }
}
