import 'package:flutter/material.dart';

/* Nesta página está apenas o Search Controller, correspondente a barra de pesquisa que é usado no BuyTrade e WareHouse Pages*/

class SearchControllerPage extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onSearchChanged;
  final String hintText;

  const SearchControllerPage({
    super.key,
    required this.initialText,
    required this.onSearchChanged,
    required this.hintText,
  });

  @override
  _SearchControllerPageState createState() => _SearchControllerPageState();
}

class _SearchControllerPageState extends State<SearchControllerPage> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          child: TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged, // Alteração principal aqui
            decoration: InputDecoration(
              labelText: "Search Product",
              hintText: widget.hintText,
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}