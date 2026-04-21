import 'package:flutter/material.dart';

//donkere background rond witte rand
class CameraMaskOverlay extends StatelessWidget {
  final bool isGezicht;
  const CameraMaskOverlay({super.key, required this.isGezicht});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.7),
        BlendMode.srcOut,
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.2),
            child: Container(
              height: isGezicht ? 300 : 220,
              width: isGezicht ? 220 : 340,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isGezicht 
                  ? const BorderRadius.all(Radius.elliptical(220, 300))
                  : BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//witte rand
class CameraFocusFrame extends StatelessWidget {
  final bool isGezicht;
  const CameraFocusFrame({super.key, required this.isGezicht});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.2),
      child: Container(
        height: isGezicht ? 300 : 220,
        width: isGezicht ? 220 : 340,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: isGezicht 
              ? const BorderRadius.all(Radius.elliptical(220, 300))
              : BorderRadius.circular(15),
        ),
      ),
    );
  }
}