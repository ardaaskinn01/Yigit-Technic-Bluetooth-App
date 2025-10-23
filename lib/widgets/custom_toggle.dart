import 'package:flutter/material.dart';

typedef ToggleChanged = void Function(bool);

class CustomToggle extends StatelessWidget {
  final bool value;
  final ToggleChanged onChanged;
  final double width;
  final double height;

  const CustomToggle({
    Key? key,
    required this.value,
    required this.onChanged,
    this.width = 46,
    this.height = 26,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: value ? Colors.green : Colors.grey.shade600,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: height - 6,
            height: height - 6,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: value
                  ? [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8)]
                  : [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }
}
