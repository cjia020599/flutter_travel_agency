import 'package:flutter/material.dart';

// Design colors
const _navBlue = Color(0xFF1E3A5F);
const _topBarGrey = Color(0xFF2C3E50);
const _primaryBlue = Color(0xFF2563EB);
const _accentOrange = Color(0xFFEAB308);
const _saleRed = Color(0xFFDC2626);
const _hotPurple = Color(0xFF7C3AED);

class TravelHomePage extends StatefulWidget {
  const TravelHomePage({super.key});

  @override
  State<TravelHomePage> createState() => _TravelHomePageState();
}

class _TravelHomePageState extends State<TravelHomePage> {
  int _searchTabIndex = 0;
  final _searchTabs = ['Hotels', 'Tours', 'Flights', 'Cars'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildTopBar(),
          _buildNavBar(),
          SliverToBoxAdapter(child: _buildHero()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildSectionTitle('Trending Places', "The world's best luxury travel tours.")),
          SliverToBoxAdapter(child: _buildTrendingPlaces()),
          SliverToBoxAdapter(child: _buildSectionTitle('Top Destinations', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.')),
          SliverToBoxAdapter(child: _buildTopDestinations()),
          SliverToBoxAdapter(child: _buildSectionTitle('Our Tour Packages', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.')),
          SliverToBoxAdapter(child: _buildTourPackages()),
          SliverToBoxAdapter(child: _buildSectionTitle('Popular Tour Packages', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.')),
          SliverToBoxAdapter(child: _buildPopularPackages()),
          SliverToBoxAdapter(child: _buildSectionTitle('Checkout With Bank Event', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.')),
          SliverToBoxAdapter(child: _buildBankEvents()),
          SliverToBoxAdapter(child: _buildSectionTitle('Our Blog', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.')),
          SliverToBoxAdapter(child: _buildBlog()),
          SliverToBoxAdapter(child: _buildKnowYourCityBanner()),
          SliverToBoxAdapter(child: _buildSectionTitle('Our Guides', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.')),
          SliverToBoxAdapter(child: _buildGuides()),
          SliverToBoxAdapter(child: _buildNewsletter()),
          SliverToBoxAdapter(child: _buildFooter()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: _topBarGrey,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[300]),
                    const SizedBox(width: 8),
                    Text('+1 (800) 283 0000', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                    const SizedBox(width: 24),
                    Icon(Icons.email_outlined, size: 16, color: Colors.grey[300]),
                    const SizedBox(width: 8),
                    Text('info@domain.com', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                  ],
                ),
                if (isWide)
                  Row(
                    children: [
                      // _dropdown('EN', ['EN', 'ES', 'FR']),
                      // const SizedBox(width: 16),
                      // _dropdown('USD', ['USD', 'EUR', 'GBP']),
                      // const SizedBox(width: 24),
                      TextButton(onPressed: () {}, child: Text('Sign In', style: TextStyle(color: Colors.grey[300], fontSize: 13))),
                      TextButton(onPressed: () {}, child: Text('Register', style: TextStyle(color: Colors.grey[300], fontSize: 13))),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dropdown(String value, List<String> options) {
    return DropdownButton<String>(
      value: value,
      dropdownColor: _topBarGrey,
      underline: const SizedBox(),
      style: TextStyle(color: Colors.grey[300], fontSize: 13),
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (_) {},
    );
  }

  Widget _buildNavBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: _navBlue,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
        child: Row(
          children: [
            _buildLogo(),
            const SizedBox(width: 48),
            const _NavLink(label: 'Home'),
            const _NavLink(label: 'Tours'),
            const _NavLink(label: 'Hotel'),
            const _NavLink(label: 'Flight'),
            const _NavLink(label: 'Blog'),
            const _NavLink(label: 'Contact'),
            const Spacer(),
            // Stack(
            //   clipBehavior: Clip.none,
            //   children: [
            //     IconButton(icon: const Icon(Icons.notification_important_outlined, color: Colors.white), onPressed: () {}),
            //     Positioned(right: 4, top: 4, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: _saleRed, shape: BoxShape.circle), child: const Text('0', style: TextStyle(color: Colors.white, fontSize: 10)))),
            //   ],
            // ),
            // IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: Colors.green[700], shape: BoxShape.circle),
      child: const Center(child: Text('T', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))),
    );
  }

  Widget _buildHero() {
    return Stack(
      children: [
        Container(
          height: 520,
          width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1E3A5F).withOpacity(0.7),
                  const Color(0xFF0F172A),
                ],
              ),
            ),
          child: Image.network('https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1200', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
        ),
        Container(
          height: 520,
          width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54])),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 100, 48, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hi there!', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w300)),
              const SizedBox(height: 8),
              const Text("Let's explore the world together!", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500)),
              const SizedBox(height: 75),
              _buildSearchWidget(),
              const SizedBox(height: 16),
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              //   decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       Text('Find unforgettable experiences and deals with us.', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
              //       OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(foregroundColor: _accentOrange, side: const BorderSide(color: _accentOrange)), child: const Text('Learn More')),
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(_searchTabs.length, (i) {
                  final isActive = i == _searchTabIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _searchTabIndex = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(color: isActive ? _primaryBlue : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                      child: Text(_searchTabs[i], style: TextStyle(color: isActive ? Colors.white : Colors.grey[700], fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(hintText: 'Where are you going?', 
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)), 
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))),
                    const SizedBox(width: 12),
                    SizedBox(width: 160, child: TextField(decoration: InputDecoration(hintText: 'Check In', suffixIcon: const Icon(Icons.calendar_today, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
                    const SizedBox(width: 12),
                    SizedBox(width: 160, child: TextField(decoration: InputDecoration(hintText: 'Check Out', suffixIcon: const Icon(Icons.calendar_today, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
                    const SizedBox(width: 12),
                    SizedBox(width: 120, child: DropdownButtonFormField<String>(value: '2', decoration: InputDecoration(hintText: 'Guest', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)), items: const [DropdownMenuItem(value: '2', child: Text('2 Guest'))], onChanged: (_) {})),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.search, size: 20), label: const Text('Search'), style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                  ],
                )
              else
                Column(
                  children: [
                    TextField(decoration: InputDecoration(hintText: 'Where are you going?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(decoration: InputDecoration(hintText: 'Check In', suffixIcon: const Icon(Icons.calendar_today, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(decoration: InputDecoration(hintText: 'Check Out', suffixIcon: const Icon(Icons.calendar_today, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(value: '2', decoration: InputDecoration(hintText: 'Guest', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)), items: const [DropdownMenuItem(value: '2', child: Text('2 Guest'))], onChanged: (_) {})),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.search, size: 20), label: const Text('Search'), style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 20, 48, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _navBlue)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final items = [
      (_navBlue, 'NEW', 'Creative Hotels', 'Our Hotels are all about the experience.', Icons.hotel),
      (Colors.grey[700]!, 'SALE', 'Best Travel', 'Our trips are all about the experience.', Icons.travel_explore),
      (_navBlue, null, 'Holiday Planning', 'Our Flights are all about the experience.', Icons.flight),
      (Colors.orange[700]!, null, 'Amazing Cars', 'Our Cars are all about the experience.', Icons.directions_car),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(48,40,48,20),
      child: Row(
        children: items.map((e) {
          final (color, tag, title, desc, icon) = e;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Stack(
                children: [
                  // if (tag != null) Positioned(top: 0, left: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _saleRed, borderRadius: BorderRadius.circular(4)), child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 8), Text(desc, style: TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 16), Icon(icon, color: Colors.white54, size: 40)]),
                  Positioned(bottom: 0, right: 0, child: Icon(Icons.arrow_forward, color: Colors.white54)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendingPlaces() {
    final places = [
      ('Rome, Italy', '\$50 - \$120 / person', 4.5, true),
      ('London, UK', '\$60 - \$140 / person', 4.8, false),
      ('Paris, France', '\$70 - \$150 / person', 4.6, true),
      ('Dubai, UAE', '\$90 - \$200 / person', 4.9, false),
    ];
    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 48),
        itemCount: places.length,
        itemBuilder: (context, i) {
          final (city, price, stars, sale) = places[i];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network('https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=400', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[400]))),
                      if (sale) Positioned(top: 12, left: 12, child: _tag('SALE', _saleRed)),
                      Positioned(bottom: 12, left: 12, right: 12, child: Text(city, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(city, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(price, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Row(children: [Icon(Icons.star, size: 16, color: Colors.amber[700]), const SizedBox(width: 4), Text('$stars', style: const TextStyle(fontSize: 13))]),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)));
  }

  Widget _buildTopDestinations() {
    final cities = ['New York', 'London', 'Paris', 'Tokyo', 'Sydney', 'Dubai'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48,),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.8,
        children: cities.map((city) {
          return Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network('https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=400', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[400])),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]))),
                  Positioned(bottom: 16, left: 16, right: 16, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(city, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), Text('12 properties', style: TextStyle(color: Colors.white70, fontSize: 12))]), const Icon(Icons.arrow_forward, color: Colors.white)])),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard({String? saleTag, String title = 'Travel with us', String desc = 'Lorem ipsum dolor sit amet.', String price = '\$150 / person', double stars = 4.5, String? buttonLabel}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(height: 160, width: double.infinity, color: Colors.grey[300], child: Image.network('https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
              ),
              if (saleTag != null) Positioned(top: 12, left: 12, child: _tag(saleTag, saleTag == 'HOT' ? _hotPurple : _saleRed)),
              Positioned(bottom: 12, right: 12, child: CircleAvatar(backgroundColor: _primaryBlue, child: const Icon(Icons.check, color: Colors.white, size: 20))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [Icon(Icons.star, size: 16, color: Colors.amber[700]), const SizedBox(width: 4), Text('$stars', style: const TextStyle(fontSize: 13)), const SizedBox(width: 12), Text(price, style: const TextStyle(fontWeight: FontWeight.bold))]),
              ]),
              if (buttonLabel != null) ...[
                const SizedBox(height: 12), 
                SizedBox(
                  width: double.infinity, 
                  child: OutlinedButton(
                    onPressed: () {}, 
                    child: Text(buttonLabel)))],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildTourPackages() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.3,
        children: List.generate(6, (_) => _buildCard(buttonLabel: 'View Details')),
      ),
    );
  }

  Widget _buildPopularPackages() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1,
        children: List.generate(8, (i) {
          return _buildCard(title: '${7 - (i % 3)} Days In Switzerland', price: '\$70 / person', buttonLabel: null);
        }),
      ),
    );
  }

  Widget _buildBankEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.4,
        children: List.generate(6, (i) {
          return _buildCard(saleTag: 'HOT', title: 'Amazing Event in Paris', desc: 'Lorem ipsum dolor sit amet.', price: '\$120', buttonLabel: null);
        }),
      ),
    );
  }

  Widget _buildBlog() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.3,
        children: List.generate(6, (_) {
          return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(height: 180, width: double.infinity, color: Colors.grey[300], child: Image.network('https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=400', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Adventure Trip (Tour)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('22 March 2026', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () {}, child: const Text('Read More')),
                  ]),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKnowYourCityBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(48, 48, 48, 0),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      decoration: BoxDecoration(color: _accentOrange.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Know your city?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 8), Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut elit tellus', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14))]),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _navBlue, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Learn More')),
        ],
      ),
    );
  }

  Widget _buildGuides() {
    final guides = [('Irvin Deo', 'Travel Guide'), ('Jane Smith', 'Travel Guide'), ('John Doe', 'Travel Guide')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: guides.map((e) {
          final (name, role) = e;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 2))]),
              child: Column(children: [
                CircleAvatar(radius: 48, backgroundColor: Colors.grey[300], child: Text(name[0], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(role, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 8),
                Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit.', style: TextStyle(color: Colors.grey[500], fontSize: 12), textAlign: TextAlign.center),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNewsletter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 48, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      color: Colors.grey[200],
      child: Row(
        children: [
          Icon(Icons.mail_outline, size: 32, color: _navBlue),
          const SizedBox(width: 16),
          const Text('Join Our Newsletter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navBlue)),
          const SizedBox(width: 32),
          Expanded(child: TextField(decoration: InputDecoration(hintText: 'Enter your email', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)))),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: _navBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Subscribe')),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: _navBlue,
      padding: const EdgeInsets.fromLTRB(48, 48, 48, 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 16),
                    Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut elit tellus, luctus nec ullamcorper mattis.', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                    const SizedBox(height: 16),
                    Text('Copyright © 2026 Company Name, All Rights Reserved.', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Quick Links', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _footerLink('About us'),
                  _footerLink('Contact us'),
                  _footerLink('Privacy Policy'),
                  _footerLink('Terms & Conditions'),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Categories', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _footerLink('Adventure'),
                  _footerLink('Culture'),
                  _footerLink('Relaxation'),
                  _footerLink('Family'),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Contact Information', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text('+1 (800) 283 0000', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                  Text('info@domain.com', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                  Text('123 Street, City, Country', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.facebook, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.camera, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.white), onPressed: () {}),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white12),
        ],
      ),
    );
  }

  Widget _footerLink(String label) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: TextButton(onPressed: () {}, style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: Text(label, style: TextStyle(color: Colors.grey[300], fontSize: 14))));
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton(onPressed: () {}, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15))),
    );
  }
}
