import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class HelpPage extends StatelessWidget {
  final user = FirebaseAuth.instance.currentUser;
  String? userName;
  final List<Map<String, dynamic>> sections = [
    {'name': 'Products & Stock', 'icon': Icons.inventory, 'page': ProductsStockPage()},
    {'name': 'Stock Locations', 'icon': Icons.business, 'page': StockLocationsPage()},
    {'name': 'Warehouse Stock', 'icon': Icons.local_shipping, 'page': WarehouseStockPage()},
    {'name': 'Stock Brakes', 'icon': Icons.remove_shopping_cart, 'page': StockBrakesPage()},
    {'name': 'Notifications & Alerts', 'icon': Icons.notifications, 'page': NotificationsAlertsPage()},
    {'name': 'Account Settings', 'icon': Icons.settings, 'page': AccountSettingsHelpPage()},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white10,
        title: Text('Help', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Text
            Text(
              'Help Page - User Guide',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Welcome to the Help Page! This guide will walk you through how to use the application, '
              'so you can easily filter products, view details, and find exactly what you\'re looking for.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SizedBox(height: 24), // Add space before the list of sections
            // List of Sections
            Expanded(
              child: ListView.builder(
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                      leading: Icon(section['icon'], color: Colors.blueAccent, size: 30),
                      title: Text(
                        section['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueAccent,
                        ),
                      ),
                      onTap: () {
                        // Navigate to the selected section's page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => section['page'],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Define pages as per the previous sections with consistent design
class ProductsStockPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Products & Stock Help Page', style: TextStyle(fontSize: 24)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Title
              Text(
                'Products & Stock Documentation',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 16),
              
              // Introduction
              Text(
                'In this section, you can manage the products and their stock. '
                'You can view and filter products, check stock levels, and update product details.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 20),

              // What You Can Do Section
              Text(
                'What You Can Do',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 10),
              Text(
                'This page helps you filter products based on several criteria to make finding the right items faster and easier. '
                'Here\'s what you can do:',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              BulletPointText('Search for Products by Name, Brand, or Category'),
              BulletPointText('Filter Products by Price Range'),
              BulletPointText('View Detailed Product Information'),
              BulletPointText('See Products Associated with Your Store (Only if logged in your store)'),
              SizedBox(height: 20),

              // Main Features Section
              Text(
                'Main Features',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 10),
              FeatureSection(
                title: '1. Filter Products by Name, Brand, and Category',
                description: 'At the top of the screen, you\'ll see fields where you can enter the Name, Brand, and Category of the products you\'re looking for. '
                    'Simply type in the name of the product, its brand, or category, and the list of products will automatically update to show items that match your search.',
              ),
              FeatureSection(
                title: '2. Filter by Price Range',
                description: 'There\'s a Price Range dropdown that lets you select a range (e.g., \$100-\$200, \$5000+). This will filter the products to show only those within the selected price range.',
              ),
              FeatureSection(
                title: '3. View Products from Your Store',
                description: 'If you are logged in your store, the app will automatically display products that belong to your store. The Store Number field will automatically fill with your store number, and the app will filter products to show only those that match your store.',
              ),
              FeatureSection(
                title: '4. Product List',
                description: 'The filtered products will appear below the filters. Each product will show: '
                    'Name of the product, Brand of the product, Base Price, and Current Stock available. Scroll through the list to find the product you\'re looking for.',
              ),
              FeatureSection(
                title: '5. Product Details',
                description: 'If you\'re interested in a specific product, simply tap on it to view more detailed information. '
                    'A pop-up will show: Brand, Model, Category, Description of the product, Base Price, and how much stock is available.',
              ),
              SizedBox(height: 20),

              // How to Use Section
              Text(
                'How to Use the Page',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 10),
              Text(
                'Search for Products:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Enter a product name, brand, or category in the filter fields at the top of the page. Choose a price range if you have a specific budget. '
                'The product list will update automatically to show products that match your filters.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                'View the Product List:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Scroll through the list of filtered products. You\'ll see the name, brand, price, and stock of each product.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                'View Product Details:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Tap on any product to see more information about it, including its description, model, category, and current stock.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),

              // Why Some Products May Not Appear Section
              Text(
                'Why Some Products May Not Appear',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 10),
              Text(
                'Store Number:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'If you\'re logged in your store, the app automatically filters products for your store. '
                'If your store number is missing or empty, no products will show up until the store number is set up correctly.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                'Filters:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'If you don\'t see any results, try adjusting your filters (name, brand, category, or price) to make sure they are set correctly. '
                'Double-check that the store number is correct and the products you\'re looking for match the criteria.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),

              // Additional Tips Section
              Text(
                'Additional Tips',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 10),
              Text(
                'Loading:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'When you first open the app, it might take a few seconds to load the data. Please be patient. A loading spinner will appear during this time.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                'Clear Filters:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'If you want to remove a filter, simply delete the text from the filter fields or reset the price range. '
                'The product list will update automatically based on the new criteria.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),

              // Summary Section
              Text(
                'In Summary',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 10),
              Text(
                'Enter search criteria: Name, brand, category, or price range.\n'
                'View filtered products: Scroll through the list of products that match your criteria.\n'
                'Tap on a product: Get detailed information like the brand, model, and stock.\n'
                'Stay logged in: The app will show products only related to your store when you\'re logged in.\n'
                'If you have any more questions or need assistance, don’t hesitate to reach out to our support team.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30)
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to create bullet points
  Widget BulletPointText(String text) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: Colors.blueAccent),
        SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 16))),
      ],
    );
  }

  // Helper widget for each feature section
  Widget FeatureSection({required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class StockLocationsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock Location Help Page', style: TextStyle(fontSize: 24)),
        backgroundColor: Colors.white10,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Stock Locations Documentation',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              SizedBox(height: 16),

              // What You Can Do
              _buildSectionHeader('What You Can Do'),
              _buildBulletPoint('Search for Products by Name, Brand, or Category'),
              _buildBulletPoint('Filter Products by Store Number'),
              _buildBulletPoint('View Detailed Product Information'),
              _buildBulletPoint('Update Product Location (If you’re logged in your store)'),
              SizedBox(height: 16),
              Divider(color: Colors.lightBlueAccent, thickness: 2),  // Divider after "What You Can Do"

              // Main Features
              _buildSectionHeader('Main Features'),
              _buildSubHeader('Filter Products by Name, Brand, and Category'),
              Text(
                'At the top of the screen, you\'ll find fields to enter the Name, Brand, and Category of the products you\'re looking for. Simply type in the name, brand, or category, and the list of products will automatically update to show items that match your search.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              _buildSubHeader('Filter by Store Number'),
              Text(
                'If you\'re logged into your store, the Store Number field will automatically fill with your store\'s number. The app will filter products to show only those belonging to your store.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              _buildSubHeader('View Products from Your Store'),
              Text(
                'If you’re logged in, only products associated with your store will be shown. Products are filtered based on the Store Number, and the app will display only products relevant to your store.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              Divider(color: Colors.lightBlueAccent, thickness: 2),  // Divider after "Main Features"

              // Product List
              _buildSectionHeader('Product List'),
              Text(
                'The filtered products will appear below the filter options. Each product will show:',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              _buildBulletPoint('Name'),
              _buildBulletPoint('Brand'),
              _buildBulletPoint('Model'),
              _buildBulletPoint('Current Stock Availability'),
              _buildBulletPoint('Shop Location'),
              SizedBox(height: 16),
              Divider(color: Colors.lightBlueAccent, thickness: 2),  // Divider after "Product List"

              // How to Use the Page
              _buildSectionHeader('How to Use the Page'),
              _buildSubHeader('Search for Products'),
              Text(
                'Enter a product name, brand, or category in the filter fields at the top of the page. You can also filter by store number if you need results related only to your store.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              _buildSubHeader('View the Product List'),
              Text(
                'Scroll through the list of filtered products. Each product will show its name, brand, stock, and location.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              _buildSubHeader('View Product Details'),
              Text(
                'Tap on any product to get detailed information like its brand, model, stock level, and location.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              _buildSubHeader('Update Product Location'),
              Text(
                'If you\'re logged in your store, you can tap on a product to edit and update its location in your store. This option will appear in the product details dialog.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              Divider(color: Colors.lightBlueAccent, thickness: 2),  // Divider after "How to Use the Page"

              // Why Some Products May Not Appear
              _buildSectionHeader('Why Some Products May Not Appear'),
              _buildSubHeader('Store Number'),
              Text(
                'If you are logged in with a store account, the app filters products based on your store\'s number. If no products are showing, ensure that your store number is correctly set in the app.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              _buildSubHeader('Filters'),
              Text(
                'If no results appear, try adjusting the search filters (name, brand, category, or store number) to make sure they\'re correct.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              Divider(color: Colors.lightBlueAccent, thickness: 2),  // Divider after "Why Some Products May Not Appear"

              // Additional Tips
              _buildSectionHeader('Additional Tips'),
              _buildSubHeader('Loading Time'),
              Text(
                'When you first open the app, it might take a few seconds to load the data. Please wait patiently. A loading spinner will appear during this time.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              _buildSubHeader('Clear Filters'),
              Text(
                'To remove a filter, simply delete the text from the filter fields or reset the store number. The product list will update automatically to reflect the new criteria.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 16),
              Divider(color: Colors.lightBlueAccent, thickness: 2),  // Divider after "Additional Tips"

              // In Summary
              _buildSectionHeader('In Summary'),
              _buildBulletPoint('Enter search criteria: Name, brand, category, or store number.'),
              _buildBulletPoint('View filtered products: Scroll through the list to see products matching your filters.'),
              _buildBulletPoint('Tap on a product: Access detailed information, including stock and location.'),
              _buildBulletPoint('Update product location: If you\'re logged in, you can edit the product\'s location.'),
              SizedBox(height: 16),
              Divider(color: Colors.lightBlueAccent, thickness: 2),  // Divider after "In Summary"

              // Support
              Text(
                'If you need help or have any questions, feel free to contact our support team.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 33),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to create section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  // Helper method to create subheaders
  Widget _buildSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  // Helper method for bullet points
  Widget _buildBulletPoint(String text) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: Colors.blueAccent),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

class WarehouseStockPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Warehouse Stock Help Page', style: TextStyle(fontSize: 24))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Wrapping the Column with SingleChildScrollView
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Warehouse Filtered Page - User Guide',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 16),
              Text(
                'Welcome to the Warehouse Filtered Page!\nThis page allows you to view and filter products in your warehouse based on different criteria such as ',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Text(
                'name, brand, category, and store number. '
                'It also gives you the ability to view product details and update their location.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(), // Horizontal line
              SizedBox(height: 16),
              Text(
                'How to Use the Warehouse Filtered Page',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 8),
              Text(
                '1. What Can You Do on This Page?\n\n'
                '• Search Products: You can filter products by name, brand, category, and store number.\n'
                '• View Product Details: Tap on any product to view more details like its brand, model, warehouse stock, and location.\n'
                '• Edit Product Location: If needed, you can update the location of products directly from the details page.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(),
              SizedBox(height: 16),
              Text(
                '2. How to Filter Products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '• Name: Type the product\'s name to filter the results.\n'
                '• Brand: Enter the brand name to narrow down the search.\n'
                '• Category: If you\'re looking for products in a specific category, type it in the category field.\n'
                '• Store Number: The store number is automatically filled based on your account. You cannot edit this field.\n\n'
                'As you type in any of these fields, the products list will automatically update to show only the products that match your criteria.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(),
              SizedBox(height: 16),
              Text(
                '3. Viewing Products',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Once you have applied your filters, a list of products matching your criteria will appear. Each product card shows:\n'
                '• Product Name\n'
                '• Brand\n'
                '• Model\n'
                '• Warehouse Stock\n'
                '• Warehouse Location\n\n'
                'If you want more details about a product, just tap on the product card. A dialog will appear with more information, including the option to edit the product’s location.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(),
              SizedBox(height: 16),
              Text(
                '4. Editing Product Location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'To edit the location of a product:\n'
                '• Tap on the product card.\n'
                '• In the product details dialog, tap on the "Location" field.\n'
                '• You’ll be able to enter a new location. If the field is left empty, it will be marked as "Not located".\n'
                '• After entering the location, click Save to update the product\'s location in the system.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(),
              SizedBox(height: 16),
              Text(
                '5. What Happens if No Products Are Found?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '• If no products appear after applying filters, it means that no products match your search criteria.\n'
                '• If your store number is missing or incorrect, no products will be displayed. Ensure your account is linked to a valid store number.\n'
                '• If there are no products in the warehouse stock, they will not appear either.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(),
              SizedBox(height: 16),
              Text(
                '6. Why is the Store Number Field Disabled?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'The store number field is automatically populated based on your user account. You cannot change or edit this field. It is used to filter products that belong to your specific store.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(),
              SizedBox(height: 16),
              Text(
                '7. Can I Filter by Price Range?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Yes! You can filter products based on price. The options available are:\n'
                '• 5000+ for products priced at 5000 and above.\n'
                '• Custom price ranges (e.g., 1000-5000), where you can set your minimum and maximum price.\n\n'
                'Select a price range from the dropdown to refine your search.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(),
              SizedBox(height: 16),
              Text(
                'Frequently Asked Questions (FAQ)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 8),
              Text(
                'Q: Why aren\'t any products showing up?\n'
                'A: Ensure your user account has a valid store number linked to it. If there is no store number, products will not appear. Also, check that the products are available in your warehouse stock (greater than 0).',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'Q: Why can\'t I edit the location of some products?\n'
                'A: If the product\'s location is not yet set, it will show as "Not located". If the location is set, you should be able to edit it unless there is a permission issue.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'Q: How do I update the product location?\n'
                'A: Tap on the product in the list to view its details, then click on the location field to edit it. After making changes, click Save.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'Q: Why is the location field showing "Not located"?\n'
                'A: If the location has not been set for that product yet, it will show "Not located". You can update it to the correct location if you have the necessary permissions.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(),
              SizedBox(height: 16),
              Text(
                'Tips for Better Searching',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 8),
              Text(
                '• Combine Filters: To get the most accurate results, combine multiple filters (e.g., name, brand, and category).\n'
                '• Search as You Type: The list updates instantly as you type in the filter fields, making it easy to narrow down your search without needing to hit a search button.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              Divider(),
              SizedBox(height: 16),
              Text(
                'In Summary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 8),
              Text(
                'The Warehouse Filtered Page is a powerful tool that helps you manage your warehouse stock efficiently. You can filter products based on various criteria, view detailed information, and update product locations. It\'s designed to be intuitive and responsive, so you can get the information you need quickly and easily.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 32)
            ],
          ),
        ),
      ),
    );
  }
}

class StockBrakesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stock Breakage Help Page', style: TextStyle(fontSize: 24)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              'Stock Breakage Documentation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            SizedBox(height: 16),
            Text(
              'Welcome to the Stock Breakage section. This page helps you manage product breakages and keep your inventory accurate. Follow these steps to properly mark a product as broken and update its stock.',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            SizedBox(height: 32),

            // Section 1
            Text(
              'How the Breakage Process Works',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildStepCard(
              '1. Marking Products as Broken',
              'Follow these steps to record broken products:',
              [
                'Find the Product: Use the search filters to find the product.',
                'Choose Breakage Type: Select whether the breakage is from Store Stock or Warehouse Stock.',
                'Specify the Quantity: Enter the number of broken items (from 1 to 10).',
                'Confirm Breakage: Review and confirm to update the stock.'
              ]
            ),
            SizedBox(height: 16),
            _buildStepCard(
              '2. Tracking Breakages',
              'Once confirmed, the system logs and updates the stock for auditing and inventory management.',
              [
                'Maintain Accurate Inventory: The stock will reflect the breakage immediately.',
                'Audit Breakage Records: All breakages are recorded for later review, including type and quantity.'
              ]
            ),
            SizedBox(height: 16),
            _buildStepCard(
              '3. Limitation of Breakage Quantity',
              'You can only record up to 10 damaged items at a time. For more than 10 items, please notify your supervisor.',
              []
            ),
            SizedBox(height: 32),

            // Section 2
            Text(
              'Steps to Record a Stock Breakage',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildStepCard(
              'Step 1: Search for the Product',
              'Use search filters to locate the product you want to mark as broken:',
              [
                'Product Name: Enter the product name.',
                'Brand: Enter the product brand.',
                'Category: Enter the product category.',
                'Store Number: Pre-filled based on your account.'
              ]
            ),
            SizedBox(height: 16),
            _buildStepCard(
              'Step 2: Select Breakage Type',
              'Choose whether the breakage occurred in the store or warehouse stock.',
              [
                'Store Stock: If the breakage happened in the store.',
                'Warehouse Stock: If the breakage occurred in the warehouse.'
              ]
            ),
            SizedBox(height: 16),
            _buildStepCard(
              'Step 3: Specify Breakage Quantity',
              'Enter the number of broken items (1 to 10).',
              [
                'If the quantity exceeds 10, contact your supervisor.',
                'If 1 is selected, the stock will adjust by 1 item.'
              ]
            ),
            SizedBox(height: 16),
            _buildStepCard(
              'Step 4: Confirm the Breakage',
              'Click Save to confirm the breakage. The stock will update accordingly.',
              [
                'The current stock will adjust based on the quantity entered.',
                'Breakage is logged for audit purposes.'
              ]
            ),
            SizedBox(height: 16),
            _buildStepCard(
              'Step 5: Verification',
              'A dialog will appear to confirm the breakage details.',
              []
            ),
            SizedBox(height: 32),

// Additional section for troubleshooting
Text(
  'Troubleshooting',
  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
),
SizedBox(height: 16),
Text(
  'If you encounter any issues, refer to the troubleshooting tips below:',
  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
),
SizedBox(height: 16),
Column(
  children: [
    _buildTroubleshootingItem(
      'Unable to Find Product',
      'Ensure that you are logged in properly and using the correct filters.',
    ),
    _buildTroubleshootingItem(
      'Invalid Breakage Quantity',
      'Make sure the quantity is between 1 and 10. For more than 10, contact your supervisor.',
    ),
    _buildTroubleshootingItem(
      'Stock Not Updating',
      'Try refreshing the page or reaching out to technical support for assistance.',
    ),
  ],
),
SizedBox(height: 32),

          ],
        ),
      ),
    );
  }

  // Helper for displaying steps with bullet points
  Widget _buildStepCard(String title, String description, List<String> steps) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(description, style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            ...steps.map((step) => Text('• $step', style: TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

// Helper for displaying troubleshooting items
Widget _buildTroubleshootingItem(String issue, String solution) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8), // Adjusted vertical padding for spacing
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning, size: 22, color: Colors.red), // Increased icon size for better visibility
        SizedBox(width: 12), // Increased space between the icon and text
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$issue: ', // Bold issue text
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              children: [
                TextSpan(
                  text: solution, // Regular solution text
                  style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}

class NotificationsAlertsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notifications & Alerts Help Page', style: TextStyle(fontSize: 24))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications Page Documentation',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: 'The ',
                    ),
                    TextSpan(
                      text: 'Notifications Page',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ' provides users with relevant updates for their store. Notifications are displayed based on type (e.g., Order, Update, Warning) and are automatically removed if older than 3 days.',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Features Section
              Text(
                'Features:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '- ',
                    ),
                    TextSpan(
                      text: 'View Notifications',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Fetches notifications for your store, categorized by type.',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '- ',
                    ),
                    TextSpan(
                      text: 'Expiration Check',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Notifications older than 3 days are automatically deleted.',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '- ',
                    ),
                    TextSpan(
                      text: 'Time Display',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Shows the time elapsed since the notification was sent (e.g., "2 hours ago").',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '- ',
                    ),
                    TextSpan(
                      text: 'Error Handling',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Displays error messages if notifications can\'t be fetched or the store number is missing.',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // How to Use Section
              Text(
                'How to Use:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '1. ',
                    ),
                    TextSpan(
                      text: 'Store Number',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Automatically retrieved from the user\'s profile.',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '2. ',
                    ),
                    TextSpan(
                      text: 'Fetching Notifications',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Notifications are fetched for your store and displayed in order of receipt.',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '3. ',
                    ),
                    TextSpan(
                      text: 'Viewing Notifications',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Displays a message, time since it was sent, and the type (e.g., Order, Update). Categorized with different icons and colors for easy identification.',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '4. ',
                    ),
                    TextSpan(
                      text: 'Expired Notifications',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Automatically deleted if older than 3 days.',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Notification Types & Icons Section
              Text(
                'Notification Types & Icons:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '- ',
                    ),
                    TextSpan(
                      text: 'Order',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Box icon (Blue)',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '- ',
                    ),
                    TextSpan(
                      text: 'Update',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Inventory icon (Green)',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '- ',
                    ),
                    TextSpan(
                      text: 'Transfer',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Swap icon (Purple)',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '- ',
                    ),
                    TextSpan(
                      text: 'Warning',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Warning icon (Yellow)',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Troubleshooting Section
              Text(
                'Troubleshooting:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '1. ',
                    ),
                    TextSpan(
                      text: 'Notifications Not Showing',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Check if you\'re logged in correctly or refresh the page.',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '2. ',
                    ),
                    TextSpan(
                      text: 'Expired Notifications Not Removing',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Report the issue to your supervisor.',
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: '3. ',
                    ),
                    TextSpan(
                      text: 'Error Messages',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ': Ensure a stable network connection and try logging out and back in.',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Conclusion Section
              Text(
                'This page helps keep your store updated with important notifications. Ensure you check for any errors and address them promptly.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 32)
            ],
          ),
        ),
      ),
    );
  }
}

class AccountSettingsHelpPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account Settings Help Page', style: TextStyle(fontSize: 24)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Account Settings Documentation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              SizedBox(height: 16),

              // Introduction
              Text(
                'The Account Settings Page is where users can manage their personal account details and settings. '
                'This page helps users keep their information up to date and provides options for managing their account. '
                'Here\'s a quick overview of how it works and what you can assist users with:',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 16),

              // Section 1: Viewing and Updating User Information
              Text(
                '1. Viewing and Updating User Information',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'What Users Can Do:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Users can see their name, store number, and email on this page. If any of these fields are empty, '
                'the app will show them as "Not set." Users can edit their name and store number by tapping the "User Profile" button.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'How You Can Help:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a user wants to update their details, guide them to the User Profile section where they can enter new information. '
                'After editing, the information will be saved automatically.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 16),

              // Section 2: Changing Password
              Text(
                '2. Changing Password',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'What Users Can Do:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Users can request a password reset by tapping the "Change Password" button. '
                'A confirmation message will ask them if they want to receive a password reset email.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'How You Can Help:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a user forgets their password, let them know that they can request a reset. '
                'They will get an email with instructions to set a new password. Ensure that users know they need to check their email inbox (and spam folder) for the reset link.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 16),

              // Section 3: Viewing Activity History
              Text(
                '3. Viewing Activity History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'What Users Can Do:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Users can see their login/logout history by tapping the "Activity History" button.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'How You Can Help:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a user is unsure about recent account activity, guide them to the Activity History page where they can review their login sessions.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 16),

              // Section 4: Feedback and Support
              Text(
                '4. Feedback and Support',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'What Users Can Do:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Users can get in touch with customer support through the "Feedback and Support" button. '
                'This shows the support email address: helpstockflow@gmail.com.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'How You Can Help:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Direct users to the support email if they have questions or need help. Let them know that customer support is available for any issues they might encounter.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 16),

              // Section 5: Privacy Policy
              Text(
                '5. Privacy Policy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'What Users Can Do:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'The Privacy Policy button shows the privacy policy of the app, detailing how user data is handled.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'How You Can Help:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a user has concerns about privacy or data security, direct them to the privacy policy. '
                'This section can answer most questions about how their data is used.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 16),

              // Section 6: Deleting an Account
              Text(
                '6. Deleting an Account',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'What Users Can Do:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a user wants to delete their account, they can tap the Remove Account button. '
                'They will be asked to confirm their decision. If they are signed in with Google, they only need to confirm. '
                'If they are signed in with email and password, they need to re-enter their email and password to confirm.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'How You Can Help:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Deleting an account is a permanent action. If a user wants to delete their account, ensure they understand that their data will be lost. '
                'If the user is signed in with Google, you may assist them by confirming their identity. If they use email and password, ensure they enter the correct information.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 16),

              // Section 7: Signing Out
              Text(
                '7. Signing Out',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'What Users Can Do:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Users can sign out by tapping the "Sign Out" button. A confirmation message will appear to confirm if they want to log out.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'How You Can Help:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a user wants to log out, assist them in confirming the action. After they sign out, they will be directed to the login page.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 16),

              // General Tips for Assisting Users
              Text(
                'General Tips for Assisting Users:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a User Can\'t Find Their Information:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Make sure that the data in the user’s account is updated in the system (e.g., their name and store number). '
                'If the fields are empty, encourage the user to update them by entering the missing information.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'For Account Deletion:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Remind users that deleting their account will permanently erase their data, including their history. '
                'It\'s important that they’re fully certain before proceeding.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'Password Reset Issues:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a user reports not receiving a password reset email, suggest checking both the inbox and spam/junk folders. '
                'Ensure they are using the correct email address for their account.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 16),

              // How to Support Users in Troubleshooting
              Text(
                'How to Support Users in Troubleshooting:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'If Something Isn’t Saving:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a user’s changes aren’t saving (for example, their name or store number), double-check that the fields aren’t empty '
                'and remind them to tap the "Save" button.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'If They Can\'t Log In or Access Features:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'If a user cannot access their account or a feature, check if they’re logged in and connected to the internet. '
                'If needed, help them sign out and log in again.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 24)
            ],
          ),
        ),
      ),
    );
  }
}