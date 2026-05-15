import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart'; // Import the package

class ScrollingBanner extends StatelessWidget {
  const ScrollingBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext classContext) {
    return Expanded(
      child: Container(
        height: 50.0,
        color: Color(0xFF2C3E50),
        child: Marquee(
          text:
              'Welcome to Travelista, your smart and convenient travel companion. Travelista is an innovative travel agency website designed to make travel planning easier, faster, and more enjoyable for everyone. Our platform allows customers to book flights, tours, hotels, and travel packages in just a few clicks. What makes Travelista unique is our built-in AI assistant that helps clients with their travel concerns anytime. Customers can ask questions, get travel recommendations, check destinations, and receive instant assistance for their travel needs. At Travelista, our goal is to provide a hassle-free and user-friendly experience while helping travelers explore the world with confidence and convenience. Whether you are planning a vacation, business trip, or adventure getaway, Travelista is here to guide you every step of the way.',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
          scrollAxis: Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.center,
          blankSpace:
              20.0, // Space between the end of the text and the beginning of the next loop
          velocity: 30.0, // Speed of scrolling (higher number = faster)
          pauseAfterRound: const Duration(
            seconds: 1,
          ), // Optional pause before looping again
          startPadding: 10.0,
          accelerationDuration: const Duration(seconds: 1),
          accelerationCurve: Curves.linear,
          decelerationDuration: const Duration(milliseconds: 500),
          decelerationCurve: Curves.easeOut,
        ),
      ),
    );
  }
}
