import 'package:flutter/material.dart';
import 'package:stockflow/reusable_widgets/colors_utils.dart';

class StoreDashboardPage extends StatelessWidget {
  const StoreDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              hexStringToColor("5E61F4"),
              hexStringToColor("9546C4"),
              hexStringToColor("CB2B93"),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildOverviewCards(),
                const SizedBox(height: 20),
                _buildChartsSection(),
                const SizedBox(height: 20),
                _buildRecentTransactions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Store Analytics",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              "Last updated: ${DateTime.now().toString().substring(0, 10)}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.2,
      children: [
        _buildGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_bag, size: 30, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                "€1,245.80",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Average Purchase Price",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        _buildGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.trending_up, size: 30, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                "€8,745.20",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Monthly Revenue",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        _buildGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.money_off, size: 30, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                "€3,210.50",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Last Month Expenses",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        _buildGlassCard(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory, size: 30, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                "1,248",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "Total Products",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Performance Metrics",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildGlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Revenue vs Expenses (Last 6 Months)",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    "Bar Chart Placeholder",
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildGlassCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Top Selling Categories",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          "Pie Chart Placeholder",
                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildGlassCard(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Inventory Status",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildInventoryStatus(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInventoryStatus() {
    return Column(
      children: [
        _buildStatusItem("In Stock", "856", Colors.green),
        const SizedBox(height: 8),
        _buildStatusItem("Low Stock", "127", Colors.orange),
        const SizedBox(height: 8),
        _buildStatusItem("Out of Stock", "42", Colors.red),
        const SizedBox(height: 8),
        _buildStatusItem("On Order", "89", Colors.blue),
      ],
    );
  }

  Widget _buildStatusItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Recent Transactions",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildGlassCard(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              _buildTransactionRow("Product A", "€125.50", Icons.shopping_cart, Colors.green),
              const Divider(color: Colors.white24, height: 20),
              _buildTransactionRow("Product B", "€89.99", Icons.shopping_cart, Colors.green),
              const Divider(color: Colors.white24, height: 20),
              _buildTransactionRow("Supplier X", "€-450.00", Icons.local_shipping, Colors.red),
              const Divider(color: Colors.white24, height: 20),
              _buildTransactionRow("Product C", "€210.00", Icons.shopping_cart, Colors.green),
              const Divider(color: Colors.white24, height: 20),
              _buildTransactionRow("Supplier Y", "€-320.75", Icons.local_shipping, Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(String title, String amount, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white.withOpacity(0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ColorFilter.mode(Colors.white.withOpacity(0.1), BlendMode.srcOver),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(15),
            child: child,
          ),
        ),
      ),
    );
  }
}