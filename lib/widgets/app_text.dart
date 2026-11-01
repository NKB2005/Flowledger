import 'package:flutter/material.dart';
import '../core/app_colors.dart';

Text heading(String text, [double size = 18]) => Text(
  text,
  style: TextStyle(
    color: AppColor.text,
    fontSize: size,
    fontWeight: FontWeight.w800,
  ),
);
Text secondary(String text, [double size = 13]) => Text(
  text,
  style: TextStyle(color: AppColor.muted, fontSize: size),
);
