import Phaser from 'phaser';

type Dummy = { sprite: Phaser.GameObjects.Arc; hp: number };

export class GameScene extends Phaser.Scene {
  private player!: Phaser.Physics.Arcade.Sprite;
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private keys!: Record<string, Phaser.Input.Keyboard.Key>;
  private platforms!: Phaser.Physics.Arcade.StaticGroup;
  private dummies: Dummy[] = [];
  private bullets!: Phaser.Physics.Arcade.Group;
  private lastShot = 0;
  private hud!: Phaser.GameObjects.Text;

  constructor() { super('GameScene'); }

  create(): void {
    this.physics.world.setBounds(0, 0, 2200, 720);
    this.cameras.main.setBounds(0, 0, 2200, 720);
    this.add.rectangle(1100, 360, 2200, 720, 0x101827).setDepth(-10);
    this.drawBackdrop();

    this.platforms = this.physics.add.staticGroup();
    this.makePlatform(1100, 700, 2200, 40);
    this.makePlatform(420, 535, 260, 24);
    this.makePlatform(850, 430, 300, 24);
    this.makePlatform(1320, 545, 280, 24);
    this.makePlatform(1740, 410, 300, 24);

    // Draw an original placeholder player with generated texture.
    const g = this.make.graphics({ x: 0, y: 0 });
    g.fillStyle(0x55c7ff); g.fillRoundedRect(5, 3, 30, 48, 8);
    g.fillStyle(0xeaf7ff); g.fillCircle(20, 13, 7);
    g.generateTexture('player-placeholder', 40, 55); g.destroy();

    const bg = this.make.graphics({ x: 0, y: 0 });
    bg.fillStyle(0x9be7ff); bg.fillCircle(5, 5, 5);
    bg.generateTexture('bullet-placeholder', 10, 10); bg.destroy();

    this.player = this.physics.add.sprite(180, 570, 'player-placeholder');
    this.player.setSize(34, 54).setCollideWorldBounds(true).setDragX(900).setMaxVelocity(340, 650).setDepth(5);
    this.player.body!.setGravityY(950);
    this.physics.add.collider(this.player, this.platforms);

    this.makeDummy(690, 475);
    this.makeDummy(1120, 365);
    this.makeDummy(1570, 480);

    this.bullets = this.physics.add.group({ maxSize: 30 });
    this.cursors = this.input.keyboard!.createCursorKeys();
    this.keys = this.input.keyboard!.addKeys('W,A,D,SPACE,R') as Record<string, Phaser.Input.Keyboard.Key>;

    this.hud = this.add.text(18, 16, '', {
      fontFamily: 'Arial', fontSize: '18px', color: '#e8f1ff',
      backgroundColor: '#17243acc', padding: { x: 12, y: 9 }
    }).setScrollFactor(0).setDepth(20);

    this.add.text(18, 672, 'A/D or arrows: move  •  W/UP/SPACE: jetpack  •  Mouse: aim  •  Click: fire  •  R: restart', {
      fontFamily: 'Arial', fontSize: '15px', color: '#c5d3e8',
      backgroundColor: '#17243acc', padding: { x: 10, y: 7 }
    }).setScrollFactor(0).setDepth(20);

    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      if (pointer.leftButtonDown()) this.shoot(pointer);
    });
    this.input.keyboard!.on('keydown-R', () => this.scene.restart());
    this.cameras.main.startFollow(this.player, true, 0.08, 0.08);
    this.updateHud();
  }

  private drawBackdrop(): void {
    for (let x = 0; x < 2200; x += 110) {
      this.add.line(x, 0, 0, 0, 0, 720, 0x223149, 0.35).setOrigin(0);
    }
    for (let y = 0; y < 720; y += 90) {
      this.add.line(0, y, 0, 0, 2200, 0, 0x223149, 0.35).setOrigin(0);
    }
    for (let i = 0; i < 65; i++) {
      this.add.circle(Phaser.Math.Between(0, 2200), Phaser.Math.Between(30, 620),
        Phaser.Math.Between(1, 2), 0x8aa6c9, 0.35);
    }
  }

  private makePlatform(x: number, y: number, width: number, height: number): void {
    const p = this.add.rectangle(x, y, width, height, 0x344b68).setStrokeStyle(2, 0x6e8cac);
    this.physics.add.existing(p, true);
    this.platforms.add(p);
  }

  private makeDummy(x: number, y: number): void {
    const sprite = this.add.circle(x, y, 21, 0xffb454).setStrokeStyle(3, 0x713e27);
    this.physics.add.existing(sprite);
    const body = sprite.body as Phaser.Physics.Arcade.Body;
    body.setCircle(21); body.setAllowGravity(false);
    this.dummies.push({ sprite, hp: 3 });
    this.add.rectangle(x, y + 31, 38, 5, 0x2c405b);
  }

  update(): void {
    const body = this.player.body as Phaser.Physics.Arcade.Body;
    const left = this.cursors.left.isDown || this.keys.A.isDown;
    const right = this.cursors.right.isDown || this.keys.D.isDown;
    const thrust = this.cursors.up.isDown || this.keys.W.isDown || this.keys.SPACE.isDown;

    body.setAccelerationX(left ? -1500 : right ? 1500 : 0);
    body.setAccelerationY(thrust ? -1750 : 0);
    if (body.velocity.y > 620) body.setVelocityY(620);
    this.player.setRotation(Phaser.Math.Clamp(body.velocity.x / 1800, -0.12, 0.12));
    if (thrust) this.player.setTint(0xffd27a); else this.player.clearTint();

    this.bullets.children.each((child) => {
      const bullet = child as Phaser.Physics.Arcade.Image;
      if (!bullet.active) return true;
      if (bullet.x < 0 || bullet.x > 2200 || bullet.y < 0 || bullet.y > 720) bullet.destroy();
      for (const dummy of this.dummies) {
        if (!dummy.sprite.active || dummy.hp <= 0) continue;
        if (Phaser.Math.Distance.Between(bullet.x, bullet.y, dummy.sprite.x, dummy.sprite.y) < 25) {
          dummy.hp -= 1; bullet.destroy();
          dummy.sprite.setFillStyle(dummy.hp > 0 ? 0xffd27a : 0x596579);
          if (dummy.hp <= 0) dummy.sprite.setAlpha(0.35);
          break;
        }
      }
      return true;
    });
    this.updateHud();
  }

  private shoot(pointer: Phaser.Input.Pointer): void {
    if (this.time.now - this.lastShot < 220) return;
    this.lastShot = this.time.now;
    const target = pointer.positionToCamera(this.cameras.main) as Phaser.Math.Vector2;
    const direction = target.subtract(new Phaser.Math.Vector2(this.player.x, this.player.y)).normalize();
    const bullet = this.physics.add.image(this.player.x + direction.x * 30, this.player.y + direction.y * 30, 'bullet-placeholder');
    bullet.body!.setAllowGravity(false);
    bullet.setVelocity(direction.x * 850, direction.y * 850);
    this.bullets.add(bullet);
  }

  private updateHud(): void {
    const alive = this.dummies.filter(d => d.hp > 0).length;
    this.hud.setText(`SKYSHOOT  •  TARGETS ${alive}/${this.dummies.length}`);
  }
}