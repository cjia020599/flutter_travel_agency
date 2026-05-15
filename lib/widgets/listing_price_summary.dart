import 'package:flutter/material.dart';
import 'package:flutter_travel_agency/utils/listing_data_helpers.dart';
import 'package:intl/intl.dart';

const _primaryBlue = Color(0xFF2563EB);

/// Live price breakdown for tour (per guest) or car (per day × days).
class ListingPriceSummary extends StatelessWidget {
  const ListingPriceSummary({
    super.key,
    required this.entity,
    required this.isTour,
    required this.peso,
    required this.peopleCount,
    this.startDateText,
    this.endDateText,
  });

  final Map<String, dynamic> entity;
  final bool isTour;
  final String peso;
  final int peopleCount;
  final String? startDateText;
  final String? endDateText;

  @override
  Widget build(BuildContext context) {
    if (isTour) {
      return _TourPriceCard(
        entity: entity,
        peso: peso,
        guests: peopleCount,
      );
    }
    return _CarPriceCard(
      entity: entity,
      peso: peso,
      startDateText: startDateText,
      endDateText: endDateText,
    );
  }
}

class _TourPriceCard extends StatelessWidget {
  const _TourPriceCard({
    required this.entity,
    required this.peso,
    required this.guests,
  });

  final Map<String, dynamic> entity;
  final String peso;
  final int guests;

  @override
  Widget build(BuildContext context) {
    final min = ListingDataHelpers.minPeople(entity);
    final rate = ListingDataHelpers.perPersonRate(entity);
    final total = ListingDataHelpers.tourTotalForGuests(entity, guests);
    final package = ListingDataHelpers.effectivePrice(entity);

    if (rate == null) {
      return const SizedBox.shrink();
    }

    return _PriceShell(
      children: [
        Text(
          ListingDataHelpers.formatMoney(rate, peso),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _primaryBlue,
          ),
        ),
        Text(
          'per person',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 10),
        if (min > 1 && package != null)
          _line(
            'Package for $min guests',
            ListingDataHelpers.formatMoney(package, peso),
          ),
        _line('Guests selected', '$guests'),
        const Divider(height: 20),
        Row(
          children: [
            const Text(
              'Estimated total',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const Spacer(),
            Text(
              ListingDataHelpers.formatMoney(total ?? 0, peso),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          min > 1
              ? 'Price is split evenly across the minimum group ($min), then scales per guest.'
              : 'Total = per-person rate × number of guests.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
        ),
      ],
    );
  }
}

class _CarPriceCard extends StatelessWidget {
  const _CarPriceCard({
    required this.entity,
    required this.peso,
    this.startDateText,
    this.endDateText,
  });

  final Map<String, dynamic> entity;
  final String peso;
  final String? startDateText;
  final String? endDateText;

  @override
  Widget build(BuildContext context) {
    final daily = ListingDataHelpers.effectivePrice(entity);
    if (daily == null) return const SizedBox.shrink();

    int days = 1;
    if (startDateText != null &&
        endDateText != null &&
        startDateText!.isNotEmpty &&
        endDateText!.isNotEmpty) {
      try {
        final start = DateFormat('MMM dd, yyyy').parse(startDateText!);
        final end = DateFormat('MMM dd, yyyy').parse(endDateText!);
        days = ListingDataHelpers.rentalDaysInclusive(start, end);
        if (days < 1) days = 1;
      } catch (_) {
        days = 1;
      }
    }

    final total = daily * days;

    return _PriceShell(
      children: [
        Text(
          ListingDataHelpers.formatMoney(daily, peso),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _primaryBlue,
          ),
        ),
        Text(
          'per day',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 10),
        _line('Rental days', '$days'),
        const Divider(height: 20),
        Row(
          children: [
            const Text(
              'Estimated total',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const Spacer(),
            Text(
              ListingDataHelpers.formatMoney(total, peso),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Vehicle rate is per day (not per passenger).',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _PriceShell extends StatelessWidget {
  const _PriceShell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

Widget _line(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    ),
  );
}

/// Two columns on wide screens (browser landscape), single column on narrow.
class ListingResponsiveColumns extends StatelessWidget {
  const ListingResponsiveColumns({
    super.key,
    required this.info,
    required this.booking,
    this.wideBreakpoint = 720,
  });

  final Widget info;
  final Widget booking;
  final double wideBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: info),
              const SizedBox(width: 20),
              Expanded(flex: 9, child: booking),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            info,
            const SizedBox(height: 20),
            booking,
          ],
        );
      },
    );
  }
}
