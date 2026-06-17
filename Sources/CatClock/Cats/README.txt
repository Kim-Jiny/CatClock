여기에 기본 고양이 이미지를 넣으세요.

· 이 폴더(Sources/CatClock/Cats/)에 PNG(권장, 투명 배경)·JPG 등 이미지 파일을 넣으면
  앱의 "고양이 종류" 목록에 자동으로 추가됩니다.

· 파일 이름은 반드시 ASCII(영문/숫자)로 지으세요.
    예) cheese.png, gray.png
  ⚠️ 한글 등 비ASCII 파일명은 코드서명·DMG·App Store(.pkg) 패키징에서
     유니코드 정규화 문제로 빌드/제출이 깨집니다. 반드시 ASCII 로!

· 한글(또는 원하는) 표시이름은 names.json 에 매핑하세요:
    { "cheese": "치즈", "gray": "회색냥" }
  매핑이 없으면 파일명이 그대로 이름으로 표시됩니다.

· 투명 배경 PNG 를 쓰면 위젯에 박스 없이 모양대로 떠요.

· 이미지/매핑을 바꾼 뒤에는 다시 빌드하세요:
    개발 실행:  swift run
    배포 빌드:  ./build_app.sh   (또는 스토어용 ./build_app_mas.sh)

이 README.txt 와 names.json 은 이미지가 아니라서 목록에 나타나지 않습니다.
