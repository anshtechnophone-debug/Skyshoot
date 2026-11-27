import Phaser from 'phaser';

type Fighter = {
  sprite: Phaser.Physics.Arcade.Sprite;
  hp: number;
  nextShot: number;
  bot: boolean;
};

export class GameScene extends Phaser.Scene {
  private player!: Fighter;
  private bots: Fighter[] = [];
  private platforms!: Phaser.Physics.Arcade.StaticGroup;
  private bullets!: Phaser.Physics.Arcade.Group;
  private cursors!: Phaser.Types.Input.Keyboard.CursorKeys;
  private keys!: Record<string, Phaser.Input.Keyboard.Key>;
  private hud!: Phaser.GameObjects.Text;
  private menuOpen = true;
  private started = false;
  private lastShot = 0;
  private moveLeft = false;
  private moveRight = false;
  private thrust = false;
  private fireHeld = false;
  private score = 0;
  private facing = 1;
  private worldWidth = 2400;
  private worldHeight = 900;

  constructor() { super('GameScene'); }

  create(): void {
    this.physics.world.setBounds(0, 0, this.worldWidth, this.worldHeight);
    this.cameras.main.setBounds(0, 0, this.worldWidth, this.worldHeight);
    this.createTextures();
    this.createArena();
    this.platforms = this.physics.add.staticGroup();
    this.addPlatform(1200, 875, this.worldWidth, 50);
    this.addPlatform(360, 690, 330, 28);
    this.addPlatform(760, 555, 300, 28);
    this.addPlatform(1190, 700, 360, 28);
    this.addPlatform(1660, 535, 340, 28);
    this.addPlatform(2080, 690, 300, 28);
    this.addPlatform(1200, 390, 240, 24);
    this.bullets = this.physics.add.group({ defaultKey: 'bullet', maxSize: 100 });

    this.player = this.makeFighter(220, 790, false);
    this.physics.add.collider(this.player.sprite, this.platforms);
    this.spawnBots();
    this.bots.forEach(bot => this.physics.add.collider(bot.sprite, this.platforms));

    this.cursors = this.input.keyboard!.createCursorKeys();
    this.keys = this.input.keyboard!.addKeys('W,A,D,SPACE') as Record<string, Phaser.Input.Keyboard.Key>;

    this.physics.add.overlap(this.bullets, this.player.sprite, (_bullet, _player) => {
      const bullet = _bullet as Phaser.Physics.Arcade.Image;
      if (bullet.getData('owner') === 'bot' && this.started) {
        bullet.destroy();
        this.damage(this.player, 12);
      }
    });
    this.input.on('pointerdown', (p: Phaser.Input.Pointer) => {
      if (this.menuOpen) return;
      if (p.pointerType === 'mouse' && p.leftButtonDown()) this.fireAt(p);
    });
    this.input.on('pointerup', () => { this.fireHeld = false; });

    this.hud = this.add.text(18, 16, '', {
      fontFamily: 'Arial', fontSize: '19px', color: '#eff7ff',
      backgroundColor: '#101c30dd', padding: { x: 12, y: 9 }
    }).setScrollFactor(0).setDepth(50);
    this.createTouchControls();
    this.showOpeningScreen();
  }

  private createTextures(): void {
    const g = this.make.graphics({ x: 0, y: 0 });
    g.fillStyle(0x4dc7ff); g.fillRoundedRect(8, 4, 28, 43, 8);
    g.fillStyle(0xe9f7ff); g.fillCircle(22, 13, 8);
    g.fillStyle(0x263b55); g.fillRect(11, 37, 9, 15); g.fillRect(25, 37, 9, 15);
    g.generateTexture('hero', 44, 56); g.clear();
    g.fillStyle(0xffa65c); g.fillRoundedRect(8, 4, 28, 43, 8);
    g.fillStyle(0xffead9); g.fillCircle(22, 13, 8);
    g.fillStyle(0x503d37); g.fillRect(11, 37, 9, 15); g.fillRect(25, 37, 9, 15);
    g.generateTexture('enemy', 44, 56); g.clear();
    g.fillStyle(0xffe08a); g.fillCircle(6, 6, 6);
    g.generateTexture('bullet', 12, 12); g.destroy();
  }

  private createArena(): void {
    this.add.rectangle(this.worldWidth / 2, this.worldHeight / 2, this.worldWidth, this.worldHeight, 0x111d2b).setDepth(-20);
    const bg = this.add.graphics().setDepth(-19);
    for (let x = 0; x < this.worldWidth; x += 100) {
      bg.lineStyle(1, 0x294057, 0.38).lineBetween(x, 0, x, this.worldHeight);
    }
    for (let y = 0; y < this.worldHeight; y += 90) {
      bg.lineStyle(1, 0x294057, 0.28).lineBetween(0, y, this.worldWidth, y);
    }
    // Original neon industrial skyline and cover structures, drawn in code.
    const skyline = this.add.graphics().setDepth(-5);
    for (let i = 0; i < 18; i++) {
      const x = i * 145 + 20;
      const h = 120 + ((i * 73) % 230);
      skyline.fillStyle(i % 2 ? 0x1b3045 : 0x203a50, 0.95);
      skyline.fillRoundedRect(x, 820 - h, 105, h, 7);
      skyline.fillStyle(0x57b8d8, 0.35);
      for (let wy = 0; wy < h - 25; wy +=  thirty()) {
        skyline.fillRect(x + 15, 830 - h + wy, 12, 8);
        skyline.fillRect(x + 43, 830 - h + wy, 12, 8);
        skyline.fillRect(x + 72, 830 - h + wy, 12, 8);
      }
    }
    this.add.rectangle(1200, 850, this.worldWidth, 8, 0x48c8dc).setDepth(-1).setAlpha(0.8);
    // Decorative industrial cover blocks.
    for (const [x, y, w, h] of [[570, 815, 90, 60], [1000, 815, 110, 60], [1450, 815, 100, 60], [1880, 815, 110, 60]]) {
      this.add.rectangle(x, y, w, h, 0x334b62).setStrokeStyle(3, 0x6d91ad).setDepth(2);
    }
  }

  private addPlatform(x: number, y: number, w: number, h: number): void {
    const p = this.add.rectangle(x, y, w, h, 0x344e68).setStrokeStyle(2, 0x77a1c4);
    this.physics.add.existing(p, true);
    this.platforms.add(p);
    this.add.rectangle(x, y - h / 2 + 3, w - 8, 4, 0x61d6e8).setDepth(1);
  }

  private makeFighter(x: number, y: number, bot: boolean): Fighter {
    const sprite = this.physics.add.sprite(x, y, bot ? 'enemy' : 'hero');
    sprite.setCollideWorldBounds(true).setDragX(750).setMaxVelocity(310, 650).setDepth(8);
    sprite.body!.setGravityY(1050);
    sprite.setData('fighter', true);
    return { sprite, hp: 100, nextShot: 0, bot };
  }

  private spawnBots(): void {
    this.bots = [this.makeFighter(780, 470, true), this.makeFighter(1450, 650, true), this.makeFighter(2040, 620, true)];
  }

  private showOpeningScreen(): void {
    const shade = this.add.rectangle(640, 360, 1280, 720, 0x07111f, 0.88).setScrollFactor(0).setDepth(100);
    const title = this.add.text(640, 215, 'SKYSHOOT', {
      fontFamily: 'Arial Black, Arial', fontSize: '76px', color: '#6be3ff',
      stroke: '#173d58', strokeThickness: 8
    }).setOrigin(0.5).setScrollFactor(0).setDepth(101);
    const subtitle = this.add.text(640, 290, 'JETPACK ARENA  •  TRAINING GROUNDS', {
      fontFamily: 'Arial', fontSize: '19px', color: '#c6d9ed', letterSpacing: 3
    }).setOrigin(0.5).setScrollFactor(0).setDepth(101);
    const play = this.add.rectangle(640, 405, 270, 76, 0x087eaa).setStrokeStyle(3, 0x80edff)
      .setInteractive({ useHandCursor: true }).setScrollFactor(0).setDepth(101);
    const playText = this.add.text(640, 405, 'PLAY PRACTICE', {
      fontFamily: 'Arial Black, Arial', fontSize: '25px', color: '#ffffff'
    }).setOrigin(0.5).setScrollFactor(0).setDepth(102);
    const note = this.add.text(640, 490, '3 AI opponents  •  Solo training match', {
      fontFamily: 'Arial', fontSize: '17px', color: '#a9bfd5'
    }).setOrigin(0.5).setScrollFactor(0).setDepth(101);
    play.on('pointerdown', () => {
      this.menuOpen = false;
      this.started = true;
      [shade, title, subtitle, play, playText, note].forEach(o => o.destroy());
      this.cameras.main.startFollow(this.player.sprite, true, 0.08, 0.08);
      this.hud.setText('SKYSHOOT  •  HP 100  •  BOTS 3');
    });
  }

  private createTouchControls(): void {
    const makeButton = (x: number, y: number, label: string, down: () => void, up: () => void, width = 76) => {
      const b = this.add.rectangle(x, y, width, 68, 0x24445f, 0.82).setStrokeStyle(2, 0x78dff5, 0.9)
        .setScrollFactor(0).setDepth(70).setInteractive();
      this.add.text(x, y, label, { fontFamily: 'Arial Black, Arial', fontSize: '18px', color: '#ffffff' })
        .setOrigin(0.5).setScrollFactor(0).setDepth(71);
      b.on('pointerdown', () => down());
      b.on('pointerup', () => up());
      b.on('pointerout', () => up());
    };
    makeButton(58, 620, '◀', () => this.moveLeft = true, () => this.moveLeft = false);
    makeButton(148, 620, '▶', () => this.moveRight = true, () => this.moveRight = false);
    makeButton(1110, 620, 'JET', () => this.thrust = true, () => this.thrust = false, 88);
    makeButton(1210, 620, 'FIRE', () => this.fireHeld = true, () => this.fireHeld = false, 88);
  }

  update(time: number): void {
    if (!this.started) return;
    const body = this.player.sprite.body as Phaser.Physics.Arcade.Body;
    const left = this.moveLeft || this.cursors.left.isDown || this.keys.A.isDown;
    const right = this.moveRight || this.cursors.right.isDown || this.keys.D.isDown;
    const jet = this.thrust || this.cursors.up.isDown || this.keys.W.isDown || this.keys.SPACE.isDown;
    body.setAccelerationX(left ? -1450 : right ? 1450 : 0);
    body.setAccelerationY(jet ? -1900 : 0);
    if (left) this.facing = -1;
    if (right) this.facing = 1;
    this.player.sprite.setFlipX(this.facing < 0);
    if (jet) this.player.sprite.setTint(0xffdf91); else this.player.sprite.clearTint();

    const pointer = this.input.activePointer;
    if (pointer.isDown && pointer.pointerType !== 'mouse' && pointer.y < 540) this.fireAt(pointer);
    if (this.fireHeld) this.fireAt(this.input.activePointer);

    for (const bot of this.bots) this.updateBot(bot, time);
    this.updateBullets();
    this.bots = this.bots.filter(bot => bot.hp > 0);
    if (this.bots.length === 0) {
      this.hud.setText('TRAINING COMPLETE  •  SCORE ' + this.score + '  •  PRESS R TO RESTART');
    } else {
      this.hud.setText('SKYSHOOT  •  HP ' + this.player.hp + '  •  BOTS ' + this.bots.length + '  •  SCORE ' + this.score);
    }
    if (this.player.hp <= 0) this.respawnPlayer();
  }

  private updateBot(bot: Fighter, time: number): void {
    if (bot.hp <= 0) return;
    const dx = this.player.sprite.x - bot.sprite.x;
    const dy = this.player.sprite.y - bot.sprite.y;
    const body = bot.sprite.body as Phaser.Physics.Arcade.Body;
    body.setAccelerationX(Math.abs(dx) > 170 ? Math.sign(dx) * 650 : 0);
    body.setAccelerationY(dy < -115 ? -1250 : 0);
    bot.sprite.setFlipX(dx < 0);
    if (Math.abs(dx) < 760 && time > bot.nextShot) {
      bot.nextShot = time + Phaser.Math.Between(850, 1450);
      this.spawnBullet(bot, this.player.sprite.x, this.player.sprite.y, 'bot');
    }
  }

  private fireAt(pointer: Phaser.Input.Pointer): void {
    if (this.time.now - this.lastShot < 240) return;
    this.lastShot = this.time.now;
    const target = pointer.positionToCamera(this.cameras.main) as Phaser.Math.Vector2;
    this.spawnBullet(this.player, target.x, target.y, 'player');
  }

  private spawnBullet(owner: Fighter, tx: number, ty: number, side: string): void {
    const bullet = this.bullets.get(owner.sprite.x, owner.sprite.y - 8, 'bullet') as Phaser.Physics.Arcade.Image | null;
    if (!bullet) return;
    bullet.enableBody(true, owner.sprite.x, owner.sprite.y - 8, true, true);
    bullet.setDepth(10).setData('owner', side);
    const dir = new Phaser.Math.Vector2(tx - owner.sprite.x, ty - owner.sprite.y).normalize();
    bullet.setVelocity(dir.x * 760, dir.y * 760);
    bullet.body!.setAllowGravity(false);
    bullet.setCollideWorldBounds(false);
  }

  private updateBullets(): void {
    this.bullets.children.each(child => {
      const bullet = child as Phaser.Physics.Arcade.Image;
      if (!bullet.active) return true;
      if (bullet.x < 0 || bullet.x > this.worldWidth || bullet.y < 0 || bullet.y > this.worldHeight) {
        bullet.disableBody(true, true); return true;
      }
      if (bullet.getData('owner') === 'player') {
        for (const bot of this.bots) {
          if (bot.hp > 0 && Phaser.Math.Distance.Between(bullet.x, bullet.y, bot.sprite.x, bot.sprite.y) < 28) {
            this.damage(bot, 25); bullet.disableBody(true, true);
            if (bot.hp <= 0) this.score += 100;
            break;
          }
        }
      } else if (Phaser.Math.Distance.Between(bullet.x, bullet.y, this.player.sprite.x, this.player.sprite.y) < 28) {
        this.damage(this.player, 10); bullet.disableBody(true, true);
      }
      return true;
    });
  }

  private damage(target: Fighter, amount: number): void {
    target.hp = Math.max(0, target.hp - amount);
    target.sprite.setAlpha(target.hp > 0 ? 0.65 : 0.2);
    this.time.delayedCall(90, () => { if (target.sprite.active && target.hp > 0) target.sprite.setAlpha(1); });
    if (target.hp <= 0 && target.bot) target.sprite.disableBody(true, true);
  }

  private respawnPlayer(): void {
    this.player.hp = 100;
    this.player.sprite.setPosition(220, 790).setVelocity(0, 0).setAlpha(1);
  }
}

function thirty(): number { return 30; }